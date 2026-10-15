module main

import os
import time
import bobatea as tea
import lib.cfg
import lib.documents
import lib.nanoid
import lib.syntax

struct IndentTest {
	path   string
	doc_id nanoid.ID
mut:
	c &documents.Controller2
	m EditorModel2
}

// indent_test opens `content` as a V file, with the cursor `x` graphemes into
// line `y`, indenting with tabs or with the default four spaces
fn indent_test(content string, y int, x int, tabs bool) IndentTest {
	path := os.join_path(os.temp_dir(), 'lilly_indent_${time.now().unix_nano()}.v')
	os.write_file(path, content) or { panic('failed to write temp file: ${err}') }
	mut c := &documents.Controller2{}
	doc_id := c.open_document(path) or { panic('failed to open temp document: ${err}') }
	v_syntax := syntax.resolve_from_extension('main.v') or { panic(err) }
	base := EditorWorkspaceConfig.new(cfg.default_config)
	mut m := EditorModel2{
		config:         EditorWorkspaceConfig{
			theme:                  base.theme
			leader_key:             base.leader_key
			tab_width:              base.tab_width
			relative_line_numbers:  base.relative_line_numbers
			convert_tabs_to_spaces: !tabs
		}
		doc_id:         doc_id
		doc_controller: c
		lang_syn:       v_syntax
	}
	m.token_parser.set_syntax(v_syntax)
	c.jump_cursor_to_line(doc_id, u64(y))
	c.jump_cursor_to_line_start(doc_id)
	for _ in 0 .. x {
		c.move_cursor_right(doc_id)
	}
	return IndentTest{
		path:   path
		doc_id: doc_id
		c:      c
		m:      m
	}
}

fn (mut t IndentTest) enter() {
	t.m.insert_mode_update(tea.KeyMsg{
		k_type: .special
		runes:  'enter'.runes()
	})
}

fn (mut t IndentTest) type(s string) {
	t.m.insert_mode_update(tea.KeyMsg{
		k_type: .runes
		runes:  s.runes()
	})
}

fn (t IndentTest) lines() []string {
	mut out := []string{}
	for y in 0 .. int(t.c.line_count(t.doc_id)) {
		out << (t.c.get_line_bytes(t.doc_id, u64(y)) or { []u8{} }).bytestr()
	}
	return out
}

fn (t IndentTest) cursor() (int, int) {
	y, x := t.c.cursor_line_and_x(t.doc_id)
	return int(y), int(x)
}

fn test_enter_between_braces_opens_an_indented_line_between_them() {
	mut t := indent_test('fn main() {\n\tif x \n}', 1, 6, true)
	defer { os.rm(t.path) or {} }
	t.type('{') // closed for us
	t.enter()
	assert t.lines() == ['fn main() {', '\tif x {', '\t\t', '\t}', '}']
	y, x := t.cursor()
	assert y == 2 && x == 2
	t.type('return')
	assert t.lines()[2] == '\t\treturn'
	assert t.m.insert_line_pristine_indent == false
}

fn test_enter_between_brackets_indents_by_spaces_when_set() {
	mut t := indent_test('foo()', 0, 4, false)
	defer { os.rm(t.path) or {} }
	t.enter()
	assert t.lines() == ['foo(', '    ', ')']
	y, x := t.cursor()
	assert y == 1 && x == 4
	assert t.m.insert_line_pristine_indent
}

fn test_enter_inside_a_block_indents_one_deeper_than_its_opener() {
	mut t := indent_test('fn main() {\n\tfoo()\n}', 1, 6, true)
	defer { os.rm(t.path) or {} }
	t.enter()
	assert t.lines() == ['fn main() {', '\tfoo()', '\t', '}']

	// even when the line it's opened from is indented otherwise
	mut u := indent_test('fn main() {\nfoo()\n}', 1, 5, true)
	defer { os.rm(u.path) or {} }
	u.enter()
	assert u.lines() == ['fn main() {', 'foo()', '\t', '}']
}

fn test_enter_before_a_closer_on_a_later_line_lines_it_up_with_its_opener() {
	mut t := indent_test('\tfn main() {\n\t\tfoo()}', 1, 7, true)
	defer { os.rm(t.path) or {} }
	t.enter()
	assert t.lines() == ['\tfn main() {', '\t\tfoo()', '\t}']
	y, x := t.cursor()
	assert y == 2 && x == 1
}

fn test_enter_before_an_opener_is_outside_it() {
	mut t := indent_test('if x {}', 0, 5, true)
	defer { os.rm(t.path) or {} }
	t.enter()
	assert t.lines() == ['if x ', '{}']
}

fn test_enter_in_a_comment_or_string_keeps_the_line_indent() {
	mut t := indent_test('fn main() {\n\tx := 1 // {}\n}', 1, 12, true)
	defer { os.rm(t.path) or {} }
	t.enter()
	assert t.lines() == ['fn main() {', '\tx := 1 // {', '\t}', '}']

	// a string going over lines in a block is left as written
	mut u := indent_test("fn main() {\n\tx := '\n  a\n'\n}", 2, 3, true)
	defer { os.rm(u.path) or {} }
	u.enter()
	assert u.lines() == ['fn main() {', "\tx := '", '  a', '  ', "'", '}']
}

fn test_o_opens_a_line_indented_from_the_tree() {
	mut t := indent_test('fn main() {\n}', 0, 0, true)
	defer { os.rm(t.path) or {} }
	t.m.execute_action_normal(ChordAction{
		motion: 'o'
	})
	assert t.lines() == ['fn main() {', '\t', '}']
	assert t.m.insert_line_pristine_indent
}

fn test_typing_a_closer_lines_it_up_with_its_opener() {
	mut t := indent_test('\tfn main() {\n\t\tif x {\n\t\t\tfoo()\n\t\t\t\t\t', 3, 5, true)
	defer { os.rm(t.path) or {} }
	t.type('}')
	assert t.lines() == ['\tfn main() {', '\t\tif x {', '\t\t\tfoo()', '\t\t}']
	y, x := t.cursor()
	assert y == 3 && x == 3

	// left alone after other text, or with nothing to close
	mut u := indent_test('fn main() {\n\tfoo', 1, 4, true)
	defer { os.rm(u.path) or {} }
	u.type(')')
	assert u.lines() == ['fn main() {', '\tfoo)']
	mut w := indent_test('\t\t', 0, 2, true)
	defer { os.rm(w.path) or {} }
	w.type(']')
	assert w.lines() == ['\t\t]']
}

fn test_without_syntax_enter_keeps_the_line_indent() {
	mut t := indent_test('\tfoo()', 0, 5, true)
	defer { os.rm(t.path) or {} }
	t.m.lang_syn = syntax.noop_syntax
	t.enter()
	assert t.lines() == ['\tfoo(', '\t)']
}

fn test_enter_between_brackets_with_blanks_inside_takes_them_out() {
	// `fn f() { | }`: the cursor between the blanks, at col 9
	mut t := indent_test('fn f() {  }', 0, 9, true)
	defer { os.rm(t.path) or {} }
	t.enter()
	assert t.lines() == ['fn f() {', '\t', '}']
	y, x := t.cursor()
	assert y == 1 && x == 1

	// before the closer of a bracket opened on a line above, the blanks
	// between the cursor and the closer go
	mut u := indent_test('fn f() {\n\ta  }', 1, 2, true)
	defer { os.rm(u.path) or {} }
	u.enter()
	assert u.lines() == ['fn f() {', '\ta', '}']
}

fn test_o_and_what_is_typed_on_its_line_are_undone_in_one_go() {
	mut t := indent_test('fn main() {\n\tfoo()\n}', 1, 0, true)
	defer { os.rm(t.path) or {} }
	t.m.in_focus = true
	t.m.execute_action_normal(ChordAction{
		motion: 'o'
	})
	t.m.switch_mode_update(SwitchModeMsg{
		mode: .insert
	})
	t.type('bar')
	t.m.insert_mode_update(tea.KeyMsg{
		k_type: .special
		runes:  'escape'.runes()
	})
	t.m.switch_mode_update(SwitchModeMsg{
		from: .insert
		mode: .normal
	})
	assert t.lines() == ['fn main() {', '\tfoo()', '\tbar', '}']
	t.m.execute_action_normal(ChordAction{
		motion: 'u'
	})
	assert t.lines() == ['fn main() {', '\tfoo()', '}']
}

fn test_o_left_without_typing_is_undone_in_one_go() {
	mut t := indent_test('fn main() {\n\tfoo()\n}', 1, 0, true)
	defer { os.rm(t.path) or {} }
	t.m.in_focus = true
	t.m.execute_action_normal(ChordAction{
		motion: 'o'
	})
	t.m.switch_mode_update(SwitchModeMsg{
		mode: .insert
	})
	t.m.insert_mode_update(tea.KeyMsg{
		k_type: .special
		runes:  'escape'.runes()
	})
	t.m.switch_mode_update(SwitchModeMsg{
		from: .insert
		mode: .normal
	})
	assert t.lines() == ['fn main() {', '\tfoo()', '', '}']
	t.m.execute_action_normal(ChordAction{
		motion: 'u'
	})
	assert t.lines() == ['fn main() {', '\tfoo()', '}']
}
