// Copyright 2025 The Lilly Edtior contributors
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

fn parser_for(file_name string) Parser {
	mut parser := Parser{}
	parser.set_syntax(resolve_from_extension(file_name) or { panic(err) })
	return parser
}

// lex parses each line of `code` and renders its coloured tokens as
// `text:scope`, leaving out the plain text between them
fn lex(file_name string, code string) [][]string {
	mut parser := parser_for(file_name)
	mut out := [][]string{}
	for line in code.split('\n') {
		runes := line.runes()
		out << parser.parse_line(line).filter(it.scope != .none).map('${runes[it.start..it.end].string()}:${it.scope}')
	}
	return out
}

// end_states lexes `code` and returns each line's end state by name
fn end_states(file_name string, code string) []string {
	mut parser := parser_for(file_name)
	mut out := []string{}
	for line in code.split('\n') {
		parser.parse_line(line)
		out << parser.state_name(parser.current_state())
	}
	return out
}

fn test_parser_without_a_syntax_returns_the_line_as_one_plain_token() {
	mut parser := Parser{}
	tokens := parser.parse_line('fn main() { "x" }')
	assert tokens.len == 1
	assert tokens[0].start == 0 && tokens[0].end == 17
	assert tokens[0].scope == .none
	assert parser.current_state() == 0
}

fn test_v_identifiers_keep_their_digits_and_underscores() {
	assert lex('main.v', 'utf8_len _private xfn format') == [
		['utf8_len:variable', '_private:variable', 'xfn:variable', 'format:variable'],
	]
}

fn test_v_words_are_coloured_by_their_word_list() {
	assert lex('main.v', 'pub fn f() bool { return true || none }') == [
		['pub:keyword', 'fn:keyword', 'f:function_definition', 'bool:variable', 'return:keyword_control',
			'true:literal', 'none:literal'],
	]
	assert lex('main.v', 'println(Foo{})') == [['println:builtin', 'Foo:storage_type']]
}

fn test_v_numbers_keep_their_prefix_separators_and_fraction() {
	assert lex('main.v', 'x := 0x1F + 1_000 + 3.14 + 2e10') == [
		['x:variable_definition', '0x1F:number', '1_000:number', '3.14:number', '2e10:number'],
	]
	assert lex('main.v', 'a[0..9]') == [['a:variable', '0:number', '9:number']]
}

fn test_v_string_is_one_token_including_its_quotes() {
	assert lex('main.v', 'println("This is text being printed")') == [
		['println:builtin', '"This is text being printed":string'],
	]
}

fn test_v_backslash_escapes_the_rune_after_it() {
	assert lex('main.v', 'println("say \\"hi\\"") foo') == [
		['println:builtin', '"say :string', '\\":string_escape', 'hi:string', '\\":string_escape',
			'":string', 'foo:variable'],
	]
	// an escaped backslash doesn't escape the closing quote
	assert lex('main.v', 'a := "a\\\\" + b') == [
		['a:variable_definition', '"a:string', '\\\\:string_escape', '":string', 'b:variable'],
	]
	assert end_states('main.v', 'a := "a\\\\" + b') == ['main']
}

fn test_v_rune_literal_containing_a_quote_does_not_open_a_string() {
	assert lex('main.v', 'if value[0] != `"` { rest }') == [
		['if:keyword_control', 'value:variable', '0:number', '`"`:string', 'rest:variable'],
	]
	assert lex('main.v', 'x := `\\``') == [['x:variable_definition', '`\\``:string']]
}

fn test_v_raw_string_has_no_escapes() {
	assert lex('main.v', "r'C:\\' + x") == [["r'C:\\':string", 'x:variable']]
}

fn test_v_interpolation_lexes_as_code_and_tracks_its_braces() {
	assert lex('main.v', "'a \${b + {c}} d'") == [
		["'a :string", '\${:punctuation', 'b:variable', 'c:variable', '}:punctuation', " d':string"],
	]
	assert end_states('main.v', "'a \${b\n}'") == ['main > single > interpolation', 'main']
}

fn test_v_string_carries_on_to_the_next_line() {
	assert lex('main.v', 'x := "one\ntwo" + y') == [
		['x:variable_definition', '"one:string'],
		['two":string', 'y:variable'],
	]
}

fn test_v_block_comments_nest_and_carry_across_lines() {
	assert lex('main.v', 'a /* b /* c */ d\ne */ f') == [
		['a:variable', '/* b /* c */ d:comment'],
		['e */:comment', 'f:variable'],
	]
	assert end_states('main.v', 'a /* b /* c */ d\ne */ f') == ['main > block_comment', 'main']
}

fn test_v_block_comment_opener_does_not_also_close_it() {
	assert lex('main.v', '/*/ still a comment') == [['/*/ still a comment:comment']]
	assert end_states('main.v', '/*/ still a comment') == ['main > block_comment']
}

fn test_v_line_comment_ends_with_its_line() {
	assert lex('main.v', 'f();// a "quote\nx') == [
		['f:function', '// a "quote:comment'],
		['x:variable'],
	]
	assert end_states('main.v', '// a "quote\nx') == ['main', 'main']
}

fn test_v_attributes_and_compile_time_code() {
	assert lex('main.v', '@[inline] \$if debug { @FILE }') == [
		['@[inline]:attribute', '\$if:keyword_directive', 'debug:variable', '@FILE:variable_special'],
	]
}

fn test_python_uses_hash_comments_and_not_slashes() {
	assert lex('main.py', '# say "hi\nx // 2') == [
		['# say "hi:comment'],
		['x:variable', '2:number'],
	]
}

fn test_python_triple_quoted_string_spans_lines_and_others_do_not() {
	assert lex('main.py', 'x = """doc\nstill doc""" + "a\ny"') == [
		['x:variable', '"""doc:string'],
		['still doc""":string', '"a:string'],
		['y:variable', '":string'],
	]
	assert lex('main.py', "f(rb'\\d', not None)") == [
		['f:function', "rb':string", '\\d:string_escape', "':string", 'not:keyword_operator',
			'None:literal'],
	]
}

fn test_rust_lifetime_does_not_open_a_string() {
	assert lex('main.rs', "fn f<'a>(x: &'a str) -> char { 'a' }") == [
		['fn:keyword', 'f:variable', "'a:label", 'x:variable', "'a:label", 'str:storage_type_builtin',
			'char:storage_type_builtin', "'a':string"],
	]
	assert lex('main.rs', "let nl = '\\n';") == [['let:keyword', 'nl:variable', "'\\n':string"]]
}

fn test_rust_raw_strings_macros_and_nested_comments() {
	assert lex('main.rs', 'println!("{}", r#"a "quoted" b"#); /* x /* y */ z */ Vec::new()') == [
		['println!:function_macro', '"{}":string', 'r#"a "quoted" b"#:string',
			'/* x /* y */ z */:comment', 'Vec:storage_type', 'new:function'],
	]
}

fn test_go_raw_string_has_no_escapes_and_spans_lines() {
	assert lex('main.go', 'x := `C:\\` + "a\\"b"') == [
		['x:variable', '`C:\\`:string', '"a:string', '\\":string_escape', 'b":string'],
	]
	assert end_states('main.go', 'x := `one\ntwo`') == ['main > raw', 'main']
}

fn test_c_include_names_a_file() {
	assert lex('main.c', '#include <stdio.h>\nint main(void) { return 0; }') == [
		['#include:keyword_directive', '<stdio.h>:string'],
		['int:storage_type_builtin', 'main:function', 'void:storage_type_builtin',
			'return:keyword_control', '0:number'],
	]
}

fn test_javascript_template_literals_nest() {
	assert lex('main.js', 'let s = `a \${b + `c \${d}`} e`') == [
		['let:keyword', 's:variable', '`a :string', '\${:punctuation', 'b:variable', '`c :string',
			'\${:punctuation', 'd:variable', '}:punctuation', '`:string', '}:punctuation', ' e`:string'],
	]
}

fn test_typescript_has_builtin_types() {
	assert lex('main.ts', 'let x: number = f<string>()') == [
		['let:keyword', 'x:variable', 'number:storage_type_builtin', 'f:variable',
			'string:storage_type_builtin'],
	]
}

fn test_perl_pod_runs_until_cut() {
	assert lex('main.pl', 'my \$x = 1; # c\n=pod\ndocs "\n=cut\nprint @list;') == [
		['my:keyword', '\$x:variable', '1:number', '# c:comment'],
		['=pod:comment_doc'],
		['docs ":comment_doc'],
		['=cut:comment_doc'],
		['print:variable', '@list:variable'],
	]
}

fn test_zig_builtins_and_arbitrary_width_integers() {
	assert lex('main.zig', 'const std = @import("std"); var x: u7 = @foo();') == [
		['const:keyword', 'std:variable', '@import:builtin', '"std":string', 'var:keyword', 'x:variable',
			'u7:storage_type_builtin', '@foo:builtin'],
	]
	assert lex('main.zig', '\\\\ a "multiline string') == [['\\\\ a "multiline string:string']]
}

fn test_gleam_attributes_and_strings() {
	assert lex('main.gleam', '@external(erlang, "m", "f")\npub fn main() { Nil }') == [
		['@external:attribute', 'erlang:variable', '"m":string', '"f":string'],
		['pub:keyword', 'fn:keyword', 'main:function', 'Nil:literal'],
	]
}

fn test_deep_states_are_interned_and_restored() {
	mut parser := parser_for('main.v')
	parser.parse_line("'\${ '\${ {")
	deep := parser.current_state()
	assert int(deep) >= deep_state_base
	assert parser.state_name(deep) == 'main > single > interpolation > single > interpolation > braces'

	// the same stack later gets the same state
	parser.set_state(0)
	parser.parse_line("'\${ '\${ {")
	assert parser.current_state() == deep

	parser.set_state(deep)
	parser.parse_line('} } }')
	assert parser.state_name(parser.current_state()) == 'main > single > interpolation > single'
}

const fuzz_alphabet = ['/', '*', '"', "'", '`', '\\', '#', '$', '{', '}', '[', ']', '(', ')', '@',
	'=', '<', '>', '!', ' ', '\t', 'a', 'r', 'b', 'x', '_', '0', '9', '.', 'é']

// fuzz_text gives up to 23 runs of fuzz_alphabet, picked at random
fn fuzz_text() string {
	mut line := ''
	for _ in 0 .. rand.intn(24) or { 0 } {
		line += rand.element(fuzz_alphabet) or { '' }
	}
	return line
}

// fence_fuzz_line gives line `n` of the markdown fuzz: every ninth one of
// `fences`, picked at random, and fuzz_text otherwise
fn fence_fuzz_line(n int, fences []string) string {
	if n % 9 == 0 {
		return rand.element(fences) or { '' }
	}
	return fuzz_text()
}

// every generated lexer must cover each line with tokens exactly, never
// hang, and leave parse_line and advance_state_runes in the same state
fn test_every_lexer_tiles_lines_and_agrees_with_advance_state_runes() {
	rand.seed([u32(42), 7])
	for syn in load_builtin_syntaxes() {
		file_name := 'main' + syn.extensions[0]
		mut parsing := parser_for(file_name)
		mut advancing := parser_for(file_name)
		for n in 0 .. 400 {
			mut line := fuzz_text()
			if n % 50 == 0 {
				line = '=cut'
			}
			runes := line.runes()
			tokens := parsing.parse_line(line)
			mut at := 0
			for t in tokens {
				assert t.start == at, '${syn.name}: ${line}'
				assert t.end > t.start, '${syn.name}: ${line}'
				at = t.end
			}
			assert at == runes.len, '${syn.name}: ${line}'

			advancing.advance_state_runes(runes)
			assert parsing.state_name(parsing.current_state()) == advancing.state_name(advancing.current_state()), '${syn.name}: ${line}'

			// a line's state always restores to the same stack
			state := parsing.current_state()
			name := parsing.state_name(state)
			parsing.set_state(state)
			assert parsing.state_name(parsing.current_state()) == name
		}
	}
}

fn test_v_a_function_name_is_a_definition_where_defined_and_a_call_elsewhere() {
	assert lex('main.v', 'fn (mut s Stack[T]) push[T](x T) ?int { return push(x) }') == [
		['fn:keyword', 'mut:keyword', 's:variable', 'Stack:storage_type', 'T:storage_type',
			'push:function_definition', 'T:storage_type', 'x:variable', 'T:storage_type', 'int:variable',
			'return:keyword_control', 'push:function', 'x:variable'],
	]
	assert lex('main.v', 'fn C.puts(&char) int') == [
		['fn:keyword', 'C.puts:function_definition', 'char:variable', 'int:variable'],
	]
	// only the name, not a return type or a parameter's fn type
	assert lex('main.v', 'fn f(cb fn (int) int) Result[int] {') == [
		['fn:keyword', 'f:function_definition', 'cb:variable', 'fn:keyword', 'int:variable',
			'int:variable', 'Result:storage_type', 'int:variable'],
	]
	assert lex('main.v', 'g := fn (y int) int {') == [
		['g:variable_definition', 'fn:keyword', 'y:variable', 'int:variable', 'int:variable'],
	]
}

fn test_v_types_are_definitions_where_defined() {
	assert lex('main.v', 'pub struct Stack[T] {') == [
		['pub:keyword', 'struct:keyword', 'Stack:storage_type_definition', 'T:storage_type'],
	]
	assert lex('main.v', 'enum Colour as u8 {') == [
		['enum:keyword', 'Colour:storage_type_definition', 'as:keyword'],
	]
	assert lex('main.v', 'interface Speaker {') == [
		['interface:keyword', 'Speaker:storage_type_definition'],
	]
	assert lex('main.v', 'union U {') == [['union:keyword', 'U:storage_type_definition']]
	assert lex('main.v', 'type Num = int | f64') == [
		['type:keyword', 'Num:storage_type_definition', 'int:variable', 'f64:variable'],
	]
	// not a struct literal or a type used
	assert lex('main.v', 'x = Stack[int]{}') == [
		['x:variable', 'Stack:storage_type', 'int:variable'],
	]
}

fn test_v_variables_are_definitions_where_declared() {
	assert lex('main.v', 'a, mut b := f()') == [
		['a:variable_definition', 'mut:keyword', 'b:variable_definition', 'f:function'],
	]
	assert lex('main.v', 'a, b = b, a') == [
		['a:variable', 'b:variable', 'b:variable', 'a:variable'],
	]
	assert lex('main.v', 'if x := opt {') == [
		['if:keyword_control', 'x:variable_definition', 'opt:variable'],
	]
}

fn test_v_a_body_lexes_in_the_context_around_its_function() {
	assert end_states('main.v', 'fn f(a int,\nb int) {\nx := 1\n}') == [
		'main > function > params',
		'main',
		'main',
		'main',
	]
	// a declaration without a body ends with its line
	assert end_states('main.v', 'fn C.puts(&char) int\nx := 1') == ['main', 'main']
	assert end_states('main.v', 'struct S {\n\tcb fn (int) int = unsafe { nil }\n}') == [
		'main',
		'main',
		'main',
	]
}

fn test_markdown_highlights_its_own_markup() {
	assert lex('a.md', '## A `code` title\n- see [this](https://x.y) \\*\n> quote <!-- note -->') == [
		['##:punctuation', ' A :keyword', '`code`:string', ' title:keyword'],
		['-:punctuation', '](:punctuation', 'https://x.y:string', '):punctuation', '\\*:string_escape'],
		['>:punctuation', '<!-- note -->:comment'],
	]
}

fn test_markdown_lexes_a_fence_in_its_language() {
	code := 'text\n```v\nfn main() {}\n```\ntext'
	assert lex('a.md', code) == [
		[],
		['```v:punctuation'],
		['fn:keyword', 'main:function_definition'],
		['```:punctuation'],
		[],
	]
	assert end_states('a.md', code) == ['main', 'main > v', 'main > v', 'main', 'main']
	// the info string can say more after the language, and a fence can be
	// tildes, indented up to three spaces
	assert end_states('a.md', '   ~~~~ python title="x"\n"""\n   ~~~~') == [
		'main > python',
		'main > python > triple_double',
		'main',
	]
}

fn test_markdown_fence_closes_whatever_its_code_left_open() {
	code := '```v\nx := "unclosed /*\n/* also unclosed\n```\n`code`'
	assert end_states('a.md', code) == ['main > v', 'main > v > double', 'main > v > double', 'main',
		'main']
	assert lex('a.md', code)[4] == ['`code`:string']
}

fn test_markdown_fence_in_another_language_is_one_string() {
	code := '```\n# not a heading\n```\n~~~ cobol\nx\n~~~'
	assert lex('a.md', code) == [
		['```:punctuation'],
		['# not a heading:string'],
		['```:punctuation'],
		['~~~ cobol:punctuation'],
		['x:string'],
		['~~~:punctuation'],
	]
	assert end_states('a.md', code).last() == 'main'
}

fn test_markdown_language_names_end_at_a_word_boundary() {
	// `c++` and `vlangish` aren't c and v
	assert end_states('a.md', '```c++')[0] == 'main > fence'
	assert end_states('a.md', '```vlangish')[0] == 'main > fence'
	assert end_states('a.md', '```c')[0] == 'main > c'
	assert end_states('a.md', '```go')[0] == 'main > golang'
	assert end_states('a.md', '```golang')[0] == 'main > golang'
}

// as the every-lexer fuzz, but with fences opening and closing among the
// lines, so the embedded grammars' copies are lexed too
fn test_markdown_fuzzed_with_fences_tiles_lines_and_agrees_with_advance_state_runes() {
	rand.seed([u32(7), 42])
	fences := ['```v', '```py', '~~~ rust', '```js', '```c', '```go', '```zig', '```perl', '```gleam',
		'```ts', '```', '~~~']
	mut parsing := parser_for('a.md')
	mut advancing := parser_for('a.md')
	mut entered := map[string]bool{}
	for n in 0 .. 2000 {
		line := fence_fuzz_line(n, fences)
		runes := line.runes()
		tokens := parsing.parse_line(line)
		mut at := 0
		for t in tokens {
			assert t.start == at, line
			assert t.end > t.start, line
			at = t.end
		}
		assert at == runes.len, line
		advancing.advance_state_runes(runes)
		name := parsing.state_name(parsing.current_state())
		assert name == advancing.state_name(advancing.current_state()), line
		parts := name.split(' > ')
		if parts.len > 1 {
			entered[parts[1]] = true
		}
	}
	// fences in nearly every language were entered
	assert entered.len >= 8, entered.keys().str()
}

fn test_an_escape_pops_down_to_the_context_the_embedded_code_opened_in() {
	// Markdown only opens a fence from main, so stand one up inside an
	// html_comment by hand
	mut parser := parser_for('a.md')
	names := parser.info.names
	v := names.index('v')
	// v's block_comment, the context after its root
	assert names[v + 1] == 'block_comment'
	parser.stack = [u8(0), u8(names.index('html_comment')), u8(v), u8(v + 1)]
	parser.parse_line('```')
	assert parser.state_name(parser.current_state()) == 'main > html_comment'
}

fn test_parse_line_runes_gives_what_parse_line_does() {
	code := 'fn main() {\n\ts := "a \${b} c" /* x\ny */ println(s)\n}'
	mut by_string := parser_for('main.v')
	mut by_runes := parser_for('main.v')
	for line in code.split('\n') {
		want := by_string.parse_line(line)
		got := by_runes.parse_line_runes(line.runes())
		assert got == want, line
		assert by_runes.current_state() == by_string.current_state()
	}
}

fn test_a_set_at_the_root_records_no_node() {
	mut parser := parser_for('main.v')
	names := parser.info.names
	block := u8(names.index('block_comment'))
	runes := 'x'.runes()
	set := Match{
		end:    1
		op:     .set
		target: block
	}
	// the root context is no node, so replacing it opens and closes none
	parser.stack = [u8(0)]
	parser.record_match(runes, 0, set)
	assert parser.events.len == 0

	// a context above the root is closed, and the one replacing it opened
	parser.stack = [u8(0), u8(names.index('double'))]
	parser.record_match(runes, 0, set)
	assert parser.events.map('${it.open}:${it.id}') == [
		'false:${names.index('double')}',
		'true:${block}',
	]
}

fn test_html_highlights_tags_attributes_and_entities() {
	assert lex('a.html', '<!DOCTYPE html>\n<a href="/x?a=1&amp;b" class=nav disabled>Tom &amp; Jerry</a>\n<br/> <!-- note -->') == [
		['<!DOCTYPE html>:keyword_directive'],
		['<:punctuation', 'a:keyword', 'href:attribute', '=:operator', '"/x?a=1:string',
			'&amp;:string_escape', 'b":string', 'class:attribute', '=:operator', 'nav:string',
			'disabled:attribute', '>:punctuation', '&amp;:string_escape', '</:punctuation', 'a:keyword',
			'>:punctuation'],
		['<:punctuation', 'br:keyword', '/>:punctuation', '<!-- note -->:comment'],
	]
}

fn test_html_tags_and_quoted_values_can_span_lines() {
	code := '<div\n  title="a\n  b">\n</div>'
	assert end_states('a.html', code) == ['main > tag', 'main > tag > double', 'main', 'main']
	// an unquoted value ends at the tag's close
	assert end_states('a.html', '<input value=x/>')[0] == 'main'
	assert end_states('a.html', '<input value=>')[0] == 'main'
}

fn test_html_lexes_a_script_as_javascript() {
	code := '<SCRIPT type="module">\nconst s = "</b>"\n</script>\n<p>'
	assert lex('a.html', code) == [
		['<:punctuation', 'SCRIPT:keyword', 'type:attribute', '=:operator', '"module":string',
			'>:punctuation'],
		['const:keyword', 's:variable', '"</b>":string'],
		['</:punctuation', 'script:keyword', '>:punctuation'],
		['<:punctuation', 'p:keyword', '>:punctuation'],
	]
	assert end_states('a.html', code) == ['main > script > javascript', 'main > script > javascript',
		'main', 'main']
	// the end tag closes whatever the script left open, like a string
	assert end_states('a.html', '<script>let s = `unclosed</script>') == ['main']
}

fn test_html_lexes_a_style_as_css() {
	code := '<style media="x">\np { color: red }\n</Style>\n<p>'
	assert lex('a.html', code) == [
		['<:punctuation', 'style:keyword', 'media:attribute', '=:operator', '"x":string',
			'>:punctuation'],
		['p:keyword', '{:punctuation', 'color:attribute', '::punctuation', '}:punctuation'],
		['</:punctuation', 'Style:keyword', '>:punctuation'],
		['<:punctuation', 'p:keyword', '>:punctuation'],
	]
	assert end_states('a.html', code) == ['main > style > css', 'main > style > css', 'main', 'main']
	// the end tag closes whatever the CSS left open, like a block
	assert end_states('a.html', '<style>p { content: "unclosed</style>') == ['main']
}

fn test_css_highlights_selectors_and_declarations() {
	code := 'ul > li.item:hover, #main a[href^="http"]::after {\n  --gap: 4px;\n  margin: -1.5em calc(var(--gap) * 2) 10% !important;\n  color: #fff;\n}'
	assert lex('a.css', code) == [
		['ul:keyword', '>:operator', 'li:keyword', '.item:storage_type', ':hover:label', ',:punctuation',
			'#main:variable_special', 'a:keyword', '[:punctuation', 'href:attribute', '^=:operator',
			'"http":string', ']:punctuation', '::after:label', '{:punctuation'],
		['--gap:variable_definition', '::punctuation', '4px:number', ';:punctuation'],
		['margin:attribute', '::punctuation', '-1.5em:number', 'calc:function', 'var:function',
			'--gap:variable', '2:number', '10%:number', '!important:keyword', ';:punctuation'],
		['color:attribute', '::punctuation', '#fff:number', ';:punctuation'],
		['}:punctuation'],
	]
}

fn test_css_at_rules_and_nested_rules() {
	code := '@import url(theme.css);\n@media screen and (min-width: 600px) {\n  .a {\n    color: inherit\n  }\n  &:focus { outline: none }\n}'
	assert lex('a.css', code) == [
		['@import:keyword_directive', 'url(:function', 'theme.css:string', '):function', ';:punctuation'],
		['@media:keyword_directive', 'and:keyword_operator', 'min-width:attribute', '600px:number',
			'{:punctuation'],
		['.a:storage_type', '{:punctuation'],
		['color:attribute', '::punctuation', 'inherit:literal'],
		['}:punctuation'],
		['&:keyword_operator', ':focus:label', '{:punctuation', 'outline:attribute', '::punctuation',
			'}:punctuation'],
		['}:punctuation'],
	]
	assert end_states('a.css', code) == ['main', 'main > block', 'main > block > block',
		'main > block > block > value', 'main > block', 'main > block', 'main']
}

fn test_css_comments_and_values_can_span_lines() {
	code := '/* a\n b */ p {\n  grid-template-areas:\n    "a b";\n}'
	assert end_states('a.css', code) == ['main > block_comment', 'main > block', 'main > block > value',
		'main > block', 'main']
	// a string can't span lines
	assert end_states('a.css', 'p { content: "a\n}')[1] == 'main'
	// a nested rule ends a value missing its `;`
	assert end_states('a.css', 'p {\n  color: red\n  a { b: c }\n}') == ['main > block',
		'main > block > value', 'main > block', 'main']
}
