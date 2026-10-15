module main

import os
import time
import bobatea as tea
import lib.cfg
import lib.documents
import lib.nanoid
import lib.syntax

struct ObjectTest {
	path   string
	doc_id nanoid.ID
mut:
	c &documents.Controller2
	m EditorModel2
}

// object_test opens `content` as a file named `name`, with the cursor `x`
// graphemes into line `y`, indenting with tabs
fn object_test(name string, content string, y int, x int) ObjectTest {
	path := os.join_path(os.temp_dir(), 'lilly_objects_${time.now().unix_nano()}_${name}')
	os.write_file(path, content) or { panic('failed to write temp file: ${err}') }
	mut c := &documents.Controller2{}
	doc_id := c.open_document(path) or { panic('failed to open temp document: ${err}') }
	lang := syntax.resolve_from_extension(name) or { panic(err) }
	base := EditorWorkspaceConfig.new(cfg.default_config)
	mut m := EditorModel2{
		config:          EditorWorkspaceConfig{
			theme:                  base.theme
			leader_key:             base.leader_key
			tab_width:              base.tab_width
			relative_line_numbers:  base.relative_line_numbers
			convert_tabs_to_spaces: false
		}
		doc_id:          doc_id
		doc_controller:  c
		lang_syn:        lang
		in_focus:        true
		viewport_height: 20
	}
	m.token_parser.set_syntax(lang)
	c.jump_cursor_to_line(doc_id, u64(y))
	c.jump_cursor_to_line_start(doc_id)
	for _ in 0 .. x {
		c.move_cursor_right(doc_id)
	}
	return ObjectTest{
		path:   path
		doc_id: doc_id
		c:      c
		m:      m
	}
}

fn v_object_test(content string, y int, x int) ObjectTest {
	return object_test('main.v', content, y, x)
}

// keys feeds each rune of `keys` to the editor in normal mode
fn (mut t ObjectTest) keys(keys string) []tea.Cmd {
	mut cmds := []tea.Cmd{}
	for k in keys.runes() {
		_, cmd := t.m.normal_mode_update(tea.KeyMsg{
			k_type: .runes
			runes:  [k]
		})
		cmds << cmd
	}
	return cmds
}

fn (t ObjectTest) text() string {
	mut out := []string{}
	for y in 0 .. int(t.c.line_count(t.doc_id)) {
		out << (t.c.get_line_bytes(t.doc_id, u64(y)) or { []u8{} }).bytestr()
	}
	return out.join('\n')
}

fn (t ObjectTest) cursor() (int, int) {
	y, x := t.c.cursor_line_and_x(t.doc_id)
	return int(y), int(x)
}

fn (mut t ObjectTest) done() {
	os.rm(t.path) or {}
}

// deleted gives `content` after `keys` in normal mode with the cursor `x`
// into line `y`
fn deleted(content string, y int, x int, keys string) string {
	mut t := v_object_test(content, y, x)
	defer { t.done() }
	t.keys(keys)
	return t.text()
}

fn test_delete_inside_and_around_brackets() {
	assert deleted('f(a, [1, 2])', 0, 3, 'di(') == 'f()'
	assert deleted('f(a, [1, 2])', 0, 3, 'da(') == 'f'
	assert deleted('f(a, [1, 2])', 0, 7, 'di[') == 'f(a, [])'
	assert deleted('f(a, [1, 2])', 0, 7, 'da[') == 'f(a, )'
	assert deleted('x := {1: 2}', 0, 7, 'di{') == 'x := {}'
}

fn test_closers_and_vim_names_name_the_same_objects() {
	for keys in ['di)', 'dib'] {
		assert deleted('f(a)', 0, 2, keys) == 'f()', keys
	}
	for keys in ['di}', 'diB'] {
		assert deleted('{a}', 0, 1, keys) == '{}', keys
	}
	assert deleted('[a]', 0, 1, 'di]') == '[]'
}

fn test_the_cursor_on_a_bracket_is_in_its_block() {
	assert deleted('f(g(a), b)', 0, 3, 'di(') == 'f(g(), b)'
	assert deleted('f(g(a), b)', 0, 5, 'di(') == 'f(g(), b)'
	assert deleted('f(g(a), b)', 0, 6, 'di(') == 'f()'
}

fn test_a_count_reaches_out_to_blocks_around() {
	assert deleted('f(g(a), b)', 0, 4, '2di(') == 'f()'
	assert deleted('f(g(a), b)', 0, 4, 'd2i(') == 'f()'
	assert deleted('f(g(a), b)', 0, 4, '3di(') == 'f(g(a), b)'
}

fn test_a_block_object_needs_a_block() {
	assert deleted('f(a) x', 0, 5, 'di(') == 'f(a) x'
	assert deleted('f(a) x', 0, 2, 'di[') == 'f(a) x'
}

fn test_brackets_left_open_are_passed_over() {
	// the ( is closed by the }, so it has no match and isn't a block
	assert deleted('{ ( x }', 0, 4, 'di(') == '{ ( x }'
	assert deleted('f({ ( x })', 0, 6, 'di(') == 'f()'
	// even one closed by a closer of the kind looked for
	assert deleted('f( [ x )', 0, 5, 'di(') == 'f()'
}

fn test_brackets_in_strings_and_comments_are_not_blocks() {
	assert deleted("f('(a)')", 0, 4, 'di(') == 'f()'
	assert deleted('f(a) // (b)', 0, 9, 'di(') == 'f(a) // (b)'
}

fn test_inside_a_block_on_lines_of_its_own_is_the_lines_between() {
	content := 'fn main() {\n\tfoo()\n\tbar()\n}'
	assert deleted(content, 1, 2, 'di{') == 'fn main() {\n}'
	assert deleted(content, 1, 2, 'da{') == 'fn main() '
	assert deleted('f(\n\ta, b)', 1, 1, 'di(') == 'f(\n)'
	assert deleted('f(a,\n\tb\n)', 1, 1, 'di(') == 'f(\n)'
	assert deleted('fn main() {\n}', 0, 10, 'di{') == 'fn main() {\n}'
	// the closer keeps its indent
	assert deleted('\tif x {\n\t\tfoo()\n\t}', 1, 2, 'di{') == '\tif x {\n\t}'
}

fn test_change_inside_a_block_leaves_the_cursor_inside_in_insert_mode() {
	mut t := v_object_test('f(a, b) + 1', 0, 3)
	defer { t.done() }
	cmds := t.keys('ci(')
	assert t.text() == 'f() + 1'
	y, x := t.cursor()
	assert y == 0 && x == 2
	assert cmds.last() !is tea.NoCmd, 'switches to insert mode'
}

fn test_change_inside_a_block_on_lines_of_its_own_opens_an_indented_line() {
	mut t := v_object_test('fn main() {\n\tfoo()\n\tbar()\n}', 2, 1)
	defer { t.done() }
	cmd, switching := t.m.execute_action_normal(ChordAction{
		count:    1
		operator: `c`
		motion:   'i{'
	})
	assert t.text() == 'fn main() {\n\t\n}'
	y, x := t.cursor()
	assert y == 1 && x == 1
	// stepping back out of the line end normal mode pulls it back from
	assert switching && cmd is tea.SequenceCmd
}

fn test_change_to_the_end_of_a_line_steps_back_out_in_insert_mode() {
	mut t := v_object_test("x := 'abc'", 0, 7)
	defer { t.done() }
	t.keys('ca"')
	assert t.text() == "x := 'abc'", 'not quoted by a double quote'
	t.keys("ca'")
	assert t.text() == 'x :='
	_, x := t.cursor()
	assert x == 3, 'normal mode pulled the cursor back onto the last rune'

	mut u := v_object_test('f(a)', 0, 2)
	defer { u.done() }
	cmd, _ := u.m.execute_action_normal(ChordAction{
		count:    1
		operator: `c`
		motion:   'i('
	})
	assert cmd !is tea.SequenceCmd, 'a cursor short of the line end stays put'
}

fn test_delete_inside_and_around_quotes() {
	assert deleted("x := 'abc' + y", 0, 7, "di'") == "x := '' + y"
	assert deleted("x := 'abc' + y", 0, 7, "da'") == 'x := + y'
	assert deleted('x := "abc"', 0, 7, 'di"') == 'x := ""'
	assert deleted("f('abc' )", 0, 3, "da'") == 'f()'
	// with no white space after it, `a` takes what's before
	assert deleted("f(x, 'abc')", 0, 7, "da'") == 'f(x,)'
	// nor the indent of a string starting its line
	assert deleted("\t'abc'", 0, 2, "da'") == '\t'
}

fn test_quotes_take_a_strings_prefix_and_reach_over_lines() {
	assert deleted("x := r'a\\b'", 0, 8, "di'") == "x := r''"
	assert deleted("x := r'a\\b' + y", 0, 8, "da'") == 'x := + y'
	assert deleted("x := 'a\nb\nc'", 1, 0, "di'") == "x := ''"
	// ending in the column its opening quote's line does
	assert deleted("x := '\nabcde'", 1, 0, "di'") == "x := ''"
}

fn test_a_quote_object_is_the_string_quoted_by_it() {
	// an interpolation in a "string" holding a 'string'
	content := 'x := "a \${f(\'b\')} c"'
	assert deleted(content, 0, 14, "di'") == 'x := "a \${f(\'\')} c"'
	assert deleted(content, 0, 14, 'di"') == 'x := ""'
	assert deleted(content, 0, 14, 'di(') == 'x := "a \${f()} c"'
}

fn test_an_escaped_quote_is_inside_the_string() {
	assert deleted("x := '\\'' + y", 0, 7, "di'") == "x := '' + y"
}

fn test_an_empty_string_has_nothing_inside() {
	assert deleted("x := '' + y", 0, 6, "di'") == "x := '' + y"
	assert deleted("x := '' + y", 0, 6, "da'") == 'x := + y'
}

fn test_out_of_a_string_a_quote_object_is_the_next_on_the_line() {
	assert deleted("f(x, 'abc')", 0, 0, "di'") == "f(x, '')"
	// past a quote that doesn't start one
	assert deleted('f("it\'s", \'a\')', 0, 0, "di'") == 'f("it\'s", \'\')'
	assert deleted("f(x) // 'abc'", 0, 0, "di'") == "f(x) // 'abc'"
	assert deleted("f(x)\n'abc'", 0, 0, "di'") == "f(x)\n'abc'"
}

fn test_a_comment_is_not_a_string_for_starting_with_a_quote() {
	assert deleted("f(x) //'a'", 0, 8, "di'") == "f(x) //'a'"
}

fn test_strings_quoted_back_to_back_are_apart() {
	assert deleted("x := ''''", 0, 5, "di'") == "x := ''''"
	assert deleted("x := '''a'", 0, 8, "di'") == "x := ''''"
}

fn test_a_string_left_open_has_no_inside() {
	mut t := object_test('main.py', "x = 'abc", 0, 6)
	defer { t.done() }
	t.keys("di'")
	assert t.text() == "x = 'abc"
}

fn test_a_quote_object_can_be_a_single_token() {
	assert deleted('x := `a`', 0, 5, 'di`') == 'x := ``'
	mut t := object_test('main.rs', "let c = b'x';", 0, 9)
	defer { t.done() }
	t.keys("da'")
	assert t.text() == 'let c =;'
}

fn test_a_python_docstring_is_quoted_by_three() {
	mut t := object_test('main.py', 'x = """doc"""', 0, 8)
	defer { t.done() }
	t.keys('di"')
	assert t.text() == 'x = """"""'
}

fn test_text_objects_need_a_syntax() {
	mut t := v_object_test('f(a)', 0, 2)
	defer { t.done() }
	t.m.lang_syn = syntax.noop_syntax
	t.keys('di(')
	assert t.text() == 'f(a)'
}

fn test_i_without_an_operator_still_inserts() {
	mut t := v_object_test('f(a)', 0, 2)
	defer { t.done() }
	cmds := t.keys('i')
	assert cmds.last() !is tea.NoCmd
	assert t.m.chord.state == .empty
	assert t.text() == 'f(a)'
}

fn test_visual_text_objects_select_the_object() {
	mut t := v_object_test('f(a, [1, 2])', 0, 7)
	defer { t.done() }
	t.m.switch_mode_update(SwitchModeMsg{
		mode: .visual
	})
	for k in 'i['.runes() {
		t.m.visual_mode_update(tea.KeyMsg{
			k_type: .runes
			runes:  [k]
		})
	}
	assert t.m.visual_sel_start_col or { panic('no selection') } == 6
	y, x := t.cursor()
	assert y == 0 && x == 9
	r := t.m.current_visual_range() or { panic('no range') }
	assert r.start.x == 6 && r.end.x == 10

	// the lines inside a block end with the line before its closer
	mut u := v_object_test('{\n\ta\n\tb\n}', 1, 0)
	defer { u.done() }
	u.m.switch_mode_update(SwitchModeMsg{
		mode: .visual
	})
	for k in 'a{'.runes() {
		u.m.visual_mode_update(tea.KeyMsg{
			k_type: .runes
			runes:  [k]
		})
	}
	uy, ux := u.cursor()
	assert uy == 3 && ux == 0
	// starting over from the closer, as `i{` over the `a{` selection would
	// reach out past it
	u.m.switch_mode_update(SwitchModeMsg{
		mode: .visual
	})
	u.m.select_text_object('i{', 1)
	vy, vx := u.cursor()
	assert vy == 2 && vx == 1
	assert u.m.visual_sel_start_line or { panic('no selection') } == 1
}

fn test_an_empty_block_selects_nothing() {
	mut t := v_object_test('f()', 0, 1)
	defer { t.done() }
	t.m.switch_mode_update(SwitchModeMsg{
		mode: .visual
	})
	t.m.select_text_object('i(', 1)
	assert t.m.visual_sel_start_col or { panic('no selection') } == 1
	_, x := t.cursor()
	assert x == 1
}

fn test_text_objects_are_chords() {
	mut ch := Chord{}
	ch.feed('d')
	ch.feed('2')
	ch.feed('a')
	action := ch.feed('B') or { panic('no action') }
	assert action.motion == 'a{'
	assert action.count == 2
	assert action.operator or { 0 } == `d`

	mut v := Chord{}
	v.feed_visual('i')
	assert v.feed_visual(')') or { panic('no action') }.motion == 'i('

	// an object that isn't one drops the chord
	mut x := Chord{}
	x.feed('c')
	x.feed('i')
	if _ := x.feed('z') {
		assert false, 'an action from ciz'
	}
	assert x.state == .empty
	assert x.object == 0
}

fn test_a_change_is_undone_with_what_was_typed() {
	mut t := v_object_test('fn main() {\n\tfoo()\n}', 1, 1)
	defer { t.done() }
	t.m.execute_action_normal(ChordAction{
		count:    1
		operator: `c`
		motion:   'i{'
	})
	t.m.switch_mode_update(SwitchModeMsg{
		mode: .insert
	})
	t.m.insert_mode_update(tea.KeyMsg{
		k_type: .runes
		runes:  'bar'.runes()
	})
	t.m.insert_mode_update(tea.KeyMsg{
		k_type: .special
		runes:  'escape'.runes()
	})
	assert t.text() == 'fn main() {\n\tbar\n}'
	t.keys('u')
	assert t.text() == 'fn main() {\n\tfoo()\n}'
	y, x := t.cursor()
	assert y == 1 && x == 1, 'the cursor is back where the change was made'
}

fn test_a_parameter_list_is_a_block() {
	assert deleted('fn f(a int, b int) {\n}', 0, 7, 'di(') == 'fn f() {\n}'
	assert deleted('fn f(a int) {\n\tx\n}', 1, 1, 'da{') == 'fn f(a int) '
}

fn test_a_pending_text_object_takes_the_keys_that_switch_mode() {
	// `v` while `di` waits for its object cancels it rather than leaving it
	// for the `(` after
	for keys in ['div(', 'diV(', 'dii('] {
		mut t := v_object_test('f(a, b)', 0, 3)
		t.keys(keys)
		assert t.text() == 'f(a, b)', keys
		assert t.m.mode == .normal, keys
		t.done()
	}
}

fn test_switching_mode_drops_a_half_typed_chord() {
	for pending in ['di', 'd', 'dg', '2d'] {
		mut t := v_object_test('f(a, b)', 0, 3)
		t.keys(pending)
		t.m.switch_mode_update(SwitchModeMsg{
			from: .normal
			mode: .normal
		})
		t.keys('(w')
		assert t.text() == 'f(a, b)', pending
		t.done()
	}
}

fn test_only_dd_of_the_doubled_operators_deletes_the_line() {
	assert deleted('a\nb\nc', 1, 0, 'dd') == 'a\nc'
	// yank and change aren't wired up yet, so they leave the text be
	assert deleted('a\nb\nc', 1, 0, 'yy') == 'a\nb\nc'
	assert deleted('a\nb\nc', 1, 0, 'cc') == 'a\nb\nc'
}

fn test_changing_an_empty_object_inserts_inside_it() {
	for c in [['f() + 1', '1', 'ci(', 'f(x) + 1'], ['f() + 1', '2', 'ci(', 'f(x) + 1'],
		["s := ''", '5', "ci'", "s := 'x'"], ["s := ''", '6', "ci'", "s := 'x'"]] {
		mut t := v_object_test(c[0], 0, c[1].int())
		defer { t.done() }
		t.keys(c[2])
		t.m.insert_mode_update(tea.KeyMsg{
			k_type: .runes
			runes:  [`x`]
		})
		assert t.text() == c[3], '${c[2]} with the cursor at ${c[1]}'
	}
}

// visual_keys feeds each rune of `keys` to the editor in visual mode
fn (mut t ObjectTest) visual_keys(keys string) {
	for k in keys.runes() {
		t.m.visual_mode_update(tea.KeyMsg{
			k_type: .runes
			runes:  [k]
		})
	}
}

fn test_repeating_a_visual_block_object_reaches_out_a_block() {
	// f(a, g(1, 2)): the inner parens hold cols 7 to 10, the outer 2 to 11
	mut t := v_object_test('f(a, g(1, 2))', 0, 7)
	defer { t.done() }
	t.m.switch_mode_update(SwitchModeMsg{
		mode: .visual
	})
	t.visual_keys('i(')
	mut y, mut x := t.cursor()
	assert t.m.visual_sel_start_col or { panic('no selection') } == 7
	assert y == 0 && x == 10
	t.visual_keys('i(')
	y, x = t.cursor()
	assert t.m.visual_sel_start_col or { panic('no selection') } == 2
	assert y == 0 && x == 11
	// with no block further out, the selection stays as it is
	t.visual_keys('i(')
	y, x = t.cursor()
	assert t.m.visual_sel_start_col or { panic('no selection') } == 2
	assert y == 0 && x == 11

	// a selection of one rune, as visual mode starts with, isn't a block
	// selected already
	mut u := v_object_test('g((a))', 0, 3)
	defer { u.done() }
	u.m.switch_mode_update(SwitchModeMsg{
		mode: .visual
	})
	u.visual_keys('i(')
	y, x = u.cursor()
	assert u.m.visual_sel_start_col or { panic('no selection') } == 3
	assert y == 0 && x == 3
}

fn test_a_block_object_grows_a_selection_made_backwards() {
	mut t := v_object_test('g(f(a, [1]), b)', 0, 11)
	defer { t.done() }
	t.m.switch_mode_update(SwitchModeMsg{
		mode: .visual
	})
	// from the comma after f's call, back to the a in it
	for k in 'hhhhhhhi('.runes() {
		t.m.visual_mode_update(tea.KeyMsg{
			k_type: .runes
			runes:  [k]
		})
	}
	// f's block doesn't take in the comma, so it's g's
	assert t.m.visual_sel_start_col or { panic('no selection') } == 2
	y, x := t.cursor()
	assert y == 0 && x == 13
}

fn test_a_change_left_without_typing_is_undone_in_one_go() {
	mut t := v_object_test('fn main() {\n\tfoo()\n}', 1, 1)
	defer { t.done() }
	t.keys('ci{')
	t.m.switch_mode_update(SwitchModeMsg{
		mode: .insert
	})
	t.m.insert_mode_update(tea.KeyMsg{
		k_type: .special
		runes:  'escape'.runes()
	})
	// leaving insert mode takes out the indent the change left on its line
	t.m.switch_mode_update(SwitchModeMsg{
		from: .insert
		mode: .normal
	})
	assert t.text() == 'fn main() {\n\n}'
	t.keys('u')
	assert t.text() == 'fn main() {\n\tfoo()\n}'
}

fn test_delete_in_normal_mode_is_undone_on_its_own() {
	mut t := v_object_test('abc', 0, 0)
	defer { t.done() }
	t.m.normal_mode_update(tea.KeyMsg{
		k_type: .special
		runes:  'delete'.runes()
	})
	assert t.text() == 'bc'
	t.keys('x')
	assert t.text() == 'c'
	// the x alone comes back, not the delete before it too
	t.keys('u')
	assert t.text() == 'bc'
	t.keys('u')
	assert t.text() == 'abc'
}
