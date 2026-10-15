// Copyright 2026 The Lilly Edtior contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

module syntax

import rand

struct TestLines {
mut:
	lines []string
}

fn (mut s TestLines) line_count() int {
	return s.lines.len
}

fn (mut s TestLines) line_runes(y int) []rune {
	return s.lines[y].runes()
}

fn tree_parser(file_name string) Parser {
	mut parser := Parser{}
	parser.set_syntax(resolve_from_extension(file_name) or { panic(err) })
	return parser
}

fn lines_of(code string) TestLines {
	return TestLines{
		lines: code.split('\n')
	}
}

// path describes the nodes around a position by name, outermost first
fn path(file_name string, code string, pos Pos) []string {
	mut parser := tree_parser(file_name)
	mut src := lines_of(code)
	mut tree := Tree{}
	return tree.ancestors(mut parser, mut src, pos).map(it.name)
}

const tree_sample = 'fn main() {
	x := "a \${b(1)} c"
	/* c */
}'

fn test_ancestors_nest_brackets_inside_contexts() {
	// the brace of `${` is a bracket inside the interpolation, as in code
	assert path('main.v', tree_sample, Pos{1, 14}) == ['function', '{}', 'double', 'interpolation',
		'{}', '()']
	assert path('main.v', tree_sample, Pos{1, 4}) == ['function', '{}']
	assert path('main.v', tree_sample, Pos{2, 4}) == ['function', '{}', 'block_comment']
	assert path('main.v', tree_sample, Pos{0, 3}) == ['function']
}

fn test_a_node_covers_its_delimiters_and_nothing_after() {
	// `{` is at col 10 of line 0 and `}` at col 0 of line 3
	assert path('main.v', tree_sample, Pos{0, 10}) == ['function', '{}']
	assert path('main.v', tree_sample, Pos{0, 9}) == ['function']
	assert path('main.v', tree_sample, Pos{3, 0}) == ['function', '{}']
	assert path('main.v', tree_sample, Pos{3, 1}) == []
}

fn test_end_of_and_children() {
	mut parser := tree_parser('main.v')
	mut src := lines_of(tree_sample)
	mut tree := Tree{}
	body := tree.node_at(mut parser, mut src, Pos{1, 4}) or { panic('no node') }
	assert body.start == Pos{0, 10}
	assert tree.end_of(mut parser, mut src, body, 100) or { panic('unclosed') } == Pos{3, 1}
	// the interpolation is inside the string, so it isn't a child of the body
	children := tree.children(mut parser, mut src, body, 100)
	assert children.map(it.name) == ['double', 'block_comment']
	assert children[0].start == Pos{1, 6}
	assert tree.end_of(mut parser, mut src, children[0], 100) or { panic('unclosed') } == Pos{1, 19}

	// looking no further than the node's own line
	if _ := tree.end_of(mut parser, mut src, body, 2) {
		assert false, 'found an end below the lines asked for'
	}
}

fn test_brackets_in_strings_and_comments_are_not_nodes() {
	assert path('main.v', '"(" /* [ */ x', Pos{0, 12}) == []
	assert path('main.v', "'{' // (\nx", Pos{1, 0}) == []
}

fn test_a_closing_bracket_closes_the_nearest_of_its_kind() {
	// the stray `]` is ignored
	assert path('main.v', '( ] x )', Pos{0, 4}) == ['()']
	// `}` closes the `(` left open inside it too
	assert path('main.v', '{ ( } x', Pos{0, 6}) == []
	// a bracket doesn't reach out of the context it's in
	assert path('main.v', '( "\${ ) }" x', Pos{0, 11}) == ['()']
}

fn test_a_context_closing_closes_brackets_left_open_in_it() {
	assert path('main.v', '"\${ ( }" x', Pos{0, 9}) == []
}

fn test_find_by_text_and_scope() {
	mut parser := tree_parser('main.v')
	mut src := lines_of('foo(x)\nfoo := 1\nbar(foo) // foo\n"foo"')
	mut tree := Tree{}
	calls := tree.find(mut parser, mut src, 'foo', [.function], 0, 3)
	assert calls == [Occurrence{Pos{0, 0}, .function}]
	all := tree.find(mut parser, mut src, 'foo', [], 0, 3)
	assert all.map(it.pos) == [Pos{0, 0}, Pos{1, 0}, Pos{2, 4}]
	assert tree.find(mut parser, mut src, 'foo', [], 1, 1).map(it.pos) == [Pos{1, 0}]
}

fn test_queries_leave_the_parser_reset() {
	mut parser := tree_parser('main.v')
	mut src := lines_of('/* a\nb */')
	mut tree := Tree{}
	tree.ancestors(mut parser, mut src, Pos{1, 0})
	assert parser.current_state() == 0
	assert !parser.record
	assert parser.events.len == 0
}

const tree_snippets = ['{', '}', '(', ')', '[', ']', '/*', '*/', '"', '\${', 'x', ' ', 'f(', '//',
	'fn ', 'fn f(', 'struct S ', ') {', ',']

fn random_line() string {
	mut line := ''
	for _ in 0 .. rand.intn(6) or { 0 } {
		line += rand.element(tree_snippets) or { '' }
	}
	return line
}

// tree_paths lists the nodes around a spread of positions in `src`
fn tree_paths(mut tree Tree, mut parser Parser, mut src TestLines, probes []Pos) [][]Node {
	mut out := [][]Node{}
	for p in probes {
		out << tree.ancestors(mut parser, mut src, p)
	}
	return out
}

fn test_checkpoints_kept_across_edits_agree_with_a_fresh_tree() {
	rand.seed([u32(736), 2])
	mut src := TestLines{}
	for _ in 0 .. 900 {
		src.lines << random_line()
	}
	mut parser := tree_parser('main.v')
	mut tree := Tree{}
	for i in 0 .. 300 {
		y := rand.intn(src.lines.len) or { 0 }
		// as the buffer reports them: lines y to y changed, and the lines
		// after moved by the lines added
		delta := match rand.intn(3) or { 0 } {
			0 {
				src.lines[y] = random_line()
				0
			}
			1 {
				src.lines.insert(y, random_line())
				1
			}
			else {
				src.lines.delete(y)
				-1
			}
		}
		tree.edited(y, y, delta)

		mut probes := []Pos{}
		for _ in 0 .. 4 {
			line := rand.intn(src.lines.len) or { 0 }
			probes << Pos{line, rand.intn(src.lines[line].len + 1) or { 0 }}
		}
		mut fresh := Tree{}
		mut fresh_parser := tree_parser('main.v')
		got := tree_paths(mut tree, mut parser, mut src, probes)
		want := tree_paths(mut fresh, mut fresh_parser, mut src, probes)
		assert got.map(it.map('${it.name}@${it.start}')) == want.map(it.map('${it.name}@${it.start}')), 'after edit ${i}'
	}
	assert tree.checkpoints.len > 1
}

fn test_outline_lists_nodes_open_at_and_opening_in_the_lines() {
	mut parser := tree_parser('main.v')
	mut src := lines_of(tree_sample)
	mut tree := Tree{}
	spans := tree.outline(mut parser, mut src, 1, 2)
	// the body opened above line 1, so it's included but its end isn't seen
	assert spans.map('${it.node.name}@${it.node.depth}') == ['function@0', '{}@1', 'double@2',
		'interpolation@3', '{}@4', '()@5', 'block_comment@2']
	assert spans[0].end == none
	assert spans[2].end or { panic('unclosed') } == Pos{1, 19}
	assert spans[2].node.scope == .string
	assert spans[5].node.scope == .punctuation
}

const blocks_sample = 'fn main() {
	f(a, [
		1,
	])
	/* one */
	/*
	two */
}'

fn test_blocks_are_the_nodes_that_span_lines() {
	mut parser := tree_parser('main.v')
	mut src := lines_of(blocks_sample)
	mut tree := Tree{}
	spans := tree.blocks(mut parser, mut src, 0, 7)
	// the params, the one-line comment and the brackets inside a line are left out
	assert spans.map('${it.node.name}@${it.node.depth}') == ['function@0', '{}@1', '()@2', '[]@3',
		'block_comment@2']
	assert spans.map(it.node.start.line) == [0, 0, 1, 1, 5]
	assert spans.map((it.end or { Pos{-1, -1} }).line) == [7, 7, 3, 3, 6]
	assert spans[0].end or { panic('unclosed') } == Pos{7, 1}

	// over a line, a node not closing on it is a block too
	in_line := tree.blocks(mut parser, mut src, 1, 1)
	assert in_line.map(it.node.name) == ['function', '{}', '()', '[]']
	assert in_line.all(it.end == none)
	// outline gives the one-line comment as well
	assert tree.outline(mut parser, mut src, 4, 4).map(it.node.name) == ['function', '{}',
		'block_comment']
	assert tree.blocks(mut parser, mut src, 4, 4).map(it.node.name) == ['function', '{}']
}

fn test_token_at() {
	mut parser := tree_parser('main.v')
	mut src := lines_of(tree_sample)
	mut tree := Tree{}
	tok := tree.token_at(mut parser, mut src, Pos{1, 13}) or { panic('no token') }
	assert tok.scope == .number
	assert tok.start == 13 && tok.end == 14
	if _ := tree.token_at(mut parser, mut src, Pos{1, 99}) {
		assert false, 'found a token past the end of the line'
	}
}

// node_named gives the first node named `name` around `pos`
fn node_named(mut tree Tree, mut parser Parser, mut src TestLines, pos Pos, name string) Node {
	return tree.enclosing(mut parser, mut src, pos, name) or { panic('no ${name} at ${pos}') }
}

const structure_sample = 'pub fn (mut s Stack) push(x int, f fn (int) int) ?int {
	if x > 0 {
		return f(x)
	}
	return none
}

struct Stack {
	items []int
}'

fn test_a_function_runs_from_fn_through_its_body() {
	mut parser := tree_parser('main.v')
	mut src := lines_of(structure_sample)
	mut tree := Tree{}
	f := node_named(mut tree, mut parser, mut src, Pos{2, 3}, 'function')
	assert f.start == Pos{0, 4}
	assert tree.end_of(mut parser, mut src, f, 100) or { panic('unclosed') } == Pos{5, 1}
	assert tree.children(mut parser, mut src, f, 100).map('${it.name}@${it.start.col}') == [
		'params@7',
		'params@25',
		'{}@54',
	]
	assert path('main.v', structure_sample, Pos{2, 10}) == ['function', '{}', '{}', '()']
	assert path('main.v', structure_sample, Pos{5, 1}) == []
}

fn test_a_parameter_list_is_a_bracket_too() {
	mut parser := tree_parser('main.v')
	mut src := lines_of(structure_sample)
	mut tree := Tree{}
	nodes := tree.ancestors(mut parser, mut src, Pos{0, 25})
	assert nodes.map(it.name) == ['function', 'params', '()']
	assert nodes[1].start == nodes[2].start
	assert tree.end_of(mut parser, mut src, nodes[2], 0) or { panic('unclosed') } == Pos{0, 48}
	// a fn type in it ends at the end of its parameter
	assert path('main.v', structure_sample, Pos{0, 39}) == ['function', 'params', '()', 'function',
		'params', '()']
	assert path('main.v', structure_sample, Pos{0, 45}) == ['function', 'params', '()', 'function']
	assert path('main.v', structure_sample, Pos{0, 47}) == ['function', 'params', '()']
}

fn test_types_run_from_their_keyword_through_their_braces() {
	assert path('main.v', structure_sample, Pos{8, 2}) == ['struct', '{}']
	assert path('main.v', 'enum E as u8 {\n\ta\n}', Pos{1, 1}) == ['enum', '{}']
	assert path('main.v', 'interface I {\n\tf() int\n}', Pos{1, 2}) == ['interface', '{}', '()']
	assert path('main.v', 'type T = int | f64', Pos{0, 5}) == ['type_alias']
	assert path('main.v', 'type T = int | f64', Pos{0, 10}) == []
}

fn test_a_declaration_without_a_body_ends_with_its_line() {
	code := 'fn C.puts(&char) int\nx := 1'
	assert path('main.v', code, Pos{0, 18}) == ['function']
	assert path('main.v', code, Pos{1, 0}) == []
	// and a fn typed field at its default value
	field := 'struct S {\n\tcb fn () = unsafe { nil }\n}'
	assert path('main.v', field, Pos{1, 5}) == ['struct', '{}', 'function']
	assert path('main.v', field, Pos{1, 20}) == ['struct', '{}', '{}']
}

fn test_a_bracket_left_open_in_a_signature_closes_at_the_body() {
	code := 'fn f(a int {\n\tx\n}\ny'
	mut parser := tree_parser('main.v')
	mut src := lines_of(code)
	mut tree := Tree{}
	assert path('main.v', code, Pos{1, 1}) == ['function', '{}']
	params := node_named(mut tree, mut parser, mut src, Pos{0, 5}, 'params')
	assert tree.end_of(mut parser, mut src, params, 100) or { panic('unclosed') } == Pos{0, 11}
	f := node_named(mut tree, mut parser, mut src, Pos{0, 5}, 'function')
	assert tree.end_of(mut parser, mut src, f, 100) or { panic('unclosed') } == Pos{2, 1}
	spans := tree.outline(mut parser, mut src, 0, 3)
	assert spans.map('${it.node.name}@${it.node.depth}') == ['function@0', 'params@1', '()@2',
		'{}@1']
	assert spans[1].end or { panic('unclosed') } == Pos{0, 11}
	assert spans[3].end or { panic('unclosed') } == Pos{2, 1}
	assert path('main.v', code, Pos{3, 0}) == []
}

fn test_a_bracket_doesnt_close_a_function_from_inside_its_body() {
	// the stray `)` can't reach out to the `(` around the function
	code := 'f(fn () {\n\t)\n})'
	assert path('main.v', code, Pos{1, 1}) == ['()', 'function', '{}']
	assert path('main.v', code, Pos{2, 1}) == ['()']
	assert path('main.v', code, Pos{2, 2}) == []
}

fn test_definitions_lists_the_names_defined() {
	mut parser := tree_parser('main.v')
	mut src := lines_of(structure_sample + '\nfn g() {\n\ta, b := 1, 2\n}')
	mut tree := Tree{}
	defs := tree.definitions(mut parser, mut src, 0, 100)
	assert defs.map('${it.name}:${it.scope}@${it.pos.line}') == [
		'push:function_definition@0',
		'Stack:storage_type_definition@7',
		'g:function_definition@10',
		'a:variable_definition@11',
		'b:variable_definition@11',
	]
	assert defs[0].pos == Pos{0, 21}
	assert tree.definitions(mut parser, mut src, 7, 9).map(it.name) == ['Stack']
}

fn test_a_body_closes_what_was_left_open_in_its_signature() {
	code := 'fn f[T {\n\tg()\n}'
	mut parser := tree_parser('main.v')
	mut src := lines_of(code)
	mut tree := Tree{}
	assert path('main.v', code, Pos{1, 2}) == ['function', '{}', '()']
	generics := node_named(mut tree, mut parser, mut src, Pos{0, 5}, '[]')
	assert tree.end_of(mut parser, mut src, generics, 100) or { panic('unclosed') } == Pos{0, 7}
	assert tree.children(mut parser, mut src, generics, 100) == []
	spans := tree.outline(mut parser, mut src, 0, 2)
	assert spans.map('${it.node.name}@${it.node.depth}') == ['function@0', '[]@1', '{}@1', '()@2']
	assert spans[1].end or { panic('unclosed') } == Pos{0, 7}

	// even a construct with a body of its own still open: the function's body
	// isn't taken for its
	code2 := 'fn f() struct { {\n\tx\n}\ny'
	assert path('main.v', code2, Pos{1, 1}) == ['function', '{}']
	assert path('main.v', code2, Pos{3, 0}) == []
}

fn test_a_fn_type_returned_doesnt_take_the_body() {
	code := 'fn f() fn () int {\n\tx\n}'
	assert path('main.v', code, Pos{1, 1}) == ['function', '{}']
	assert path('main.v', code, Pos{0, 7}) == ['function']
}

fn test_warming_leaves_checkpoints_a_query_agrees_with() {
	mut src := TestLines{}
	for i in 0 .. 1000 {
		src.lines << match i % 7 {
			0 { 'fn f${i}() {' }
			6 { '}' }
			else { '\tx := "a"' }
		}
	}
	mut parser := tree_parser('main.v')
	mut tree := Tree{}
	assert !tree.covers(src.lines.len)
	assert tree.covers(0)
	// a step at a time, until the checkpoints reach the last line
	assert !tree.warm(mut parser, mut src, 300)
	assert tree.checkpoints.len == 2
	assert !tree.warm(mut parser, mut src, 300)
	assert tree.warm(mut parser, mut src, 300)
	assert tree.checkpoints.len == 4
	assert tree.covers(src.lines.len)
	// the last checkpoint, at line 768, covers lines up to 1023
	assert tree.covers(1024) && !tree.covers(1025)
	// and once there, warming leaves no more
	assert tree.warm(mut parser, mut src, 300)
	assert tree.checkpoints.len == 4

	mut fresh := Tree{}
	mut fresh_parser := tree_parser('main.v')
	probes := [Pos{3, 2}, Pos{500, 1}, Pos{999, 0}, Pos{770, 3}]
	assert tree_paths(mut tree, mut parser, mut src, probes).map(it.map('${it.name}@${it.start}')) == tree_paths(mut fresh, mut fresh_parser, mut src, probes).map(it.map('${it.name}@${it.start}'))
	// warming leaves the parser as a query would
	assert parser.current_state() == 0 && parser.tokens.len == 0
}

fn test_warming_a_few_lines_at_a_time_still_gets_there() {
	mut src := TestLines{}
	for _ in 0 .. 1000 {
		src.lines << '\tx := "a"'
	}
	mut parser := tree_parser('main.v')
	mut tree := Tree{}
	// fewer lines than between checkpoints would leave none, and the next
	// warm would walk the same lines again
	mut warms := 0
	for !tree.warm(mut parser, mut src, 10) {
		warms++
		assert warms < 100, 'warming never reaches the last line'
	}
	assert tree.covers(src.lines.len)
}

const fence_sample = '# Title
```v
fn main() {
	if x {
```
after (x)
```go
func f() {}
```'

fn test_a_fence_is_a_node_named_after_its_language() {
	mut parser := tree_parser('a.md')
	mut src := lines_of(fence_sample)
	mut tree := Tree{}
	spans := tree.outline(mut parser, mut src, 0, 8)
	assert spans.map('${it.node.name}@${it.node.depth}') == ['heading@0', 'v@0', 'function@1',
		'params@2', '()@3', '{}@2', '{}@3', '()@0', 'golang@0', '()@1', '{}@1']
	// from the start of the opening fence to the end of the closing one
	assert spans[1].node.start == Pos{1, 0}
	assert spans[1].end or { panic('unclosed') } == Pos{4, 3}
	assert spans[8].end or { panic('unclosed') } == Pos{8, 3}
}

fn test_a_fence_closing_closes_what_its_code_left_open() {
	mut parser := tree_parser('a.md')
	mut src := lines_of(fence_sample)
	mut tree := Tree{}
	assert path('a.md', fence_sample, Pos{3, 6}) == ['v', 'function', '{}', '{}']
	assert path('a.md', fence_sample, Pos{5, 7}) == ['()']
	function := node_named(mut tree, mut parser, mut src, Pos{2, 0}, 'function')
	assert tree.end_of(mut parser, mut src, function, 100) or { panic('unclosed') } == Pos{4, 3}
}

fn test_definitions_are_found_in_fences() {
	mut parser := tree_parser('a.md')
	mut src := lines_of(fence_sample)
	mut tree := Tree{}
	assert tree.definitions(mut parser, mut src, 0, 8).map('${it.name}@${it.pos.line}') == [
		'main@2',
	]
}

// CountingLines counts the lines a walk reads
struct CountingLines {
mut:
	lines []string
	reads int
}

fn (mut s CountingLines) line_count() int {
	return s.lines.len
}

fn (mut s CountingLines) line_runes(y int) []rune {
	s.reads++
	return s.lines[y].runes()
}

// functions_source is `n` small functions, five lines each
fn functions_source(n int) CountingLines {
	mut src := CountingLines{}
	for i in 0 .. n {
		src.lines << 'fn f${i}(a int) {'
		src.lines << '\tif a > 0 {'
		src.lines << '\t\tprintln("\${a}")'
		src.lines << '\t}'
		src.lines << '}'
	}
	return src
}

fn warmed(mut tree Tree, mut parser Parser, mut src CountingLines) {
	for !tree.warm(mut parser, mut src, 1 << 30) {
	}
	src.reads = 0
}

fn test_an_edit_that_changes_nothing_below_keeps_the_checkpoints_there() {
	mut src := functions_source(1000)
	mut parser := tree_parser('main.v')
	mut tree := Tree{}
	warmed(mut tree, mut parser, mut src)
	before := tree.checkpoints.len
	src.lines[2] = '\t\tprintln("\${a + 1}")'
	tree.edited(2, 2, 0)
	assert !tree.covers(src.lines.len)
	// warming reaches the first checkpoint put aside, finds it unchanged and
	// takes them all back, then walks the lines after the last: hundreds of
	// lines rather than 5000
	assert tree.warm(mut parser, mut src, 1 << 30)
	assert src.reads <= 2 * checkpoint_lines
	assert tree.checkpoints.len == before
	assert tree.stale.len == 0
}

fn test_an_edit_that_changes_what_follows_walks_on_to_the_end() {
	mut src := functions_source(1000)
	mut parser := tree_parser('main.v')
	mut tree := Tree{}
	warmed(mut tree, mut parser, mut src)
	src.lines[2] = '/*'
	tree.edited(2, 2, 0)
	assert tree.warm(mut parser, mut src, 1 << 30)
	assert src.reads > 4000
	mut fresh := Tree{}
	assert tree.ancestors(mut parser, mut src, Pos{4000, 1}).last().name == 'block_comment'
	assert tree.ancestors(mut parser, mut src, Pos{4000, 1}).map(it.name) == fresh.ancestors(mut parser, mut
		src, Pos{4000, 1}).map(it.name)
}

fn test_a_node_starting_on_the_edited_line_takes_the_start_found() {
	// one function long enough to span checkpoints
	mut src := CountingLines{
		lines: ['fn main() {']
	}
	for _ in 0 .. 600 {
		src.lines << '\tx := 1'
	}
	src.lines << '}'
	mut parser := tree_parser('main.v')
	mut tree := Tree{}
	warmed(mut tree, mut parser, mut src)
	// the body's brace moves along its line
	src.lines[0] = 'fn main_renamed() {'
	tree.edited(0, 0, 0)
	assert tree.warm(mut parser, mut src, 1 << 30)
	assert src.reads <= 2 * checkpoint_lines
	nodes := tree.ancestors(mut parser, mut src, Pos{550, 1})
	assert nodes.map('${it.name}@${it.start.col}') == ['function@0', '{}@18']
}

fn test_lines_inserted_move_the_checkpoints_and_nodes_below() {
	mut src := functions_source(1000)
	mut parser := tree_parser('main.v')
	mut tree := Tree{}
	warmed(mut tree, mut parser, mut src)
	src.lines.insert(3, ['\t\tx := 1', '\t\ty := 2'])
	tree.edited(3, 4, 2)
	assert tree.warm(mut parser, mut src, 1 << 30)
	assert src.reads <= 2 * checkpoint_lines
	// line 4000 was the start of function 800, now two lines down
	assert tree.ancestors(mut parser, mut src, Pos{4003, 1}).map('${it.name}@${it.start.line}') == [
		'function@4002',
		'{}@4002',
	]
}

// edit_lines replaces `removed` lines at `y` with `added` new ones, giving
// the change as the buffer reports it: lines first to last changed, and the
// ones after moved by delta
fn edit_lines(mut src TestLines, y int, removed int, added int) (int, int, int) {
	for _ in 0 .. removed {
		if y < src.lines.len && src.lines.len > 1 {
			src.lines.delete(y)
		}
	}
	for k in 0 .. added {
		src.lines.insert(y + k, random_line())
	}
	last := if added > 0 { y + added - 1 } else { y }
	return y, last, added - removed
}

// as test_checkpoints_kept_across_edits_agree_with_a_fresh_tree, with runs of
// edits between walks, edits of several lines, and warming between them
fn test_runs_of_edits_agree_with_a_fresh_tree() {
	for seed in 0 .. 8 {
		rand.seed([u32(seed), 99])
		mut src := TestLines{}
		for _ in 0 .. 1500 {
			src.lines << random_line()
		}
		mut parser := tree_parser('main.v')
		mut tree := Tree{}
		for i in 0 .. 100 {
			for _ in 0 .. (rand.intn(3) or { 0 }) + 1 {
				y := rand.intn(src.lines.len) or { 0 }
				removed := if rand.intn(3) or { 0 } == 0 { rand.intn(4) or { 0 } } else { 0 }
				// an edit adds or removes lines, or with neither, adds one
				mut added := if removed == 0 { 1 } else { 0 }
				if rand.intn(3) or { 0 } == 0 {
					added = rand.intn(4) or { 0 }
				}
				if removed == 0 && added == 1 && rand.intn(2) or { 0 } == 0 {
					// or changes one in place
					src.lines[y] = random_line()
					tree.edited(y, y, 0)
					continue
				}
				first, last, delta := edit_lines(mut src, y, removed, added)
				tree.edited(first, last, delta)
			}
			if rand.intn(2) or { 0 } == 0 {
				tree.warm(mut parser, mut src, rand.intn(800) or { 0 })
			}
			mut probes := []Pos{}
			for _ in 0 .. 3 {
				line := rand.intn(src.lines.len) or { 0 }
				probes << Pos{line, rand.intn(src.lines[line].len + 1) or { 0 }}
			}
			mut fresh := Tree{}
			mut fresh_parser := tree_parser('main.v')
			got := tree_paths(mut tree, mut parser, mut src, probes)
			want := tree_paths(mut fresh, mut fresh_parser, mut src, probes)
			assert got.map(it.map('${it.name}@${it.start}')) == want.map(it.map('${it.name}@${it.start}')), 'seed ${seed} edit ${i}'
		}
	}
}

fn test_edits_in_a_row_keep_the_checkpoints_put_aside() {
	mut src := functions_source(1000)
	mut parser := tree_parser('main.v')
	mut tree := Tree{}
	warmed(mut tree, mut parser, mut src)
	before := tree.checkpoints.len
	// keys typed faster than walks: each edit finds the last one's stale
	// checkpoints still waiting
	for _ in 0 .. 3 {
		src.lines[2] += 'x'
		tree.edited(2, 2, 0)
	}
	src.lines.insert(3, '\t\tx := 1')
	tree.edited(3, 3, 1)
	assert tree.stale.len == before - 1
	assert tree.warm(mut parser, mut src, 1 << 30)
	assert src.reads <= 2 * checkpoint_lines
	// with the line inserted, the walk leaves one of its own at line 256
	// before reaching the first put aside, a line further down
	assert tree.checkpoints.len == before + 1
}

// walker_with sets up a walk with nodes open and an event to apply, for cases
// no grammar produces today
fn walker_with(mut tree Tree, mut parser Parser, open []Open, events []TreeEvent) Walker {
	parser.events = events
	return Walker{
		tree:   unsafe { &tree }
		parser: unsafe { &parser }
		src:    TestLines{}
		open:   open
	}
}

fn test_a_context_closing_passes_over_a_tied_one_of_its_kind() {
	mut tree := Tree{}
	mut parser := tree_parser('main.v')
	// a context, a bracket in it, then the same context tied to its body's
	// brace: the outer one closing closes all of them
	open := [
		Open{
			kind:  .context
			id:    3
			start: Pos{0, 0}
		},
		Open{
			kind:  .bracket
			id:    0
			start: Pos{0, 2}
		},
		Open{
			kind:  .context
			id:    3
			start: Pos{0, 3}
			tied:  true
		},
		Open{
			kind:  .bracket
			id:    2
			start: Pos{0, 6}
			tied:  true
		},
	]
	mut w := walker_with(mut tree, mut parser, open, [TreeEvent{
		col: 8
		id:  3
	}])
	w.apply_next()
	assert w.open.len == 0
	// the tied brace closing still closes the context tied to it
	mut b := walker_with(mut tree, mut parser, open, [
		TreeEvent{
			col:     8
			bracket: true
			id:      2
		},
	])
	b.apply_next()
	assert b.open.len == 2
	assert b.open.last().kind == .bracket
}

fn test_end_of_a_long_node_walks_from_the_last_checkpoint_it_is_open_at() {
	mut src := CountingLines{}
	src.lines << 'fn main() {'
	for _ in 0 .. 10000 {
		src.lines << '\tx := [1, 2]'
	}
	src.lines << '}'
	src.lines << 'fn other() {}'
	mut parser := tree_parser('main.v')
	mut tree := Tree{}
	warmed(mut tree, mut parser, mut src)
	body := tree.ancestors(mut parser, mut src, Pos{5, 1})[0]
	assert tree.end_of(mut parser, mut src, body, src.lines.len) or { Pos{} } == Pos{10001, 1}
	assert src.reads <= 2 * checkpoint_lines, 'read ${src.reads} lines'
	// one that doesn't close as far down as it's asked to look
	assert tree.end_of(mut parser, mut src, body, 5000) == none
}

// end_of, which starts from the checkpoints, finds what a walk from the top
// of a fresh tree finds, across runs of edits
fn test_end_of_after_edits_agrees_with_a_fresh_tree() {
	for seed in 0 .. 2 {
		rand.seed([u32(seed), 17])
		mut src := TestLines{}
		for _ in 0 .. 1500 {
			src.lines << random_line()
		}
		mut parser := tree_parser('main.v')
		mut tree := Tree{}
		for i in 0 .. 25 {
			y := rand.intn(src.lines.len) or { 0 }
			first, last, delta := edit_lines(mut src, y, rand.intn(3) or { 0 }, rand.intn(3) or { 0 })
			tree.edited(first, last, delta)
			if rand.intn(2) or { 0 } == 0 {
				tree.warm(mut parser, mut src, rand.intn(1500) or { 0 })
			}
			line := rand.intn(src.lines.len) or { 0 }
			pos := Pos{line, rand.intn(src.lines[line].len + 1) or { 0 }}
			for node in tree.ancestors(mut parser, mut src, pos) {
				max_lines := rand.intn(src.lines.len) or { 0 }
				mut fresh := Tree{}
				mut fresh_parser := tree_parser('main.v')
				got := tree.end_of(mut parser, mut src, node, max_lines)
				want := fresh.end_of(mut fresh_parser, mut src, node, max_lines)
				assert '${got}' == '${want}', 'seed ${seed} edit ${i} ${node.name}@${node.start}'
			}
		}
	}
}
