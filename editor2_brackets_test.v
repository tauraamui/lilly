module main

import os
import bobatea as tea
import time
import lib.cfg
import lib.documents
import lib.syntax

// bracket_test_editor opens `content` as a V file, with the cursor `x`
// graphemes into line `y`
fn bracket_test_editor(content string, y int, x int) (EditorModel2, &documents.Controller2, string) {
	path := os.join_path(os.temp_dir(), 'lilly_brackets_${time.now().unix_nano()}.v')
	os.write_file(path, content) or { panic('failed to write temp file: ${err}') }
	mut c := &documents.Controller2{}
	doc_id := c.open_document(path) or { panic('failed to open temp document: ${err}') }
	v_syntax := syntax.resolve_from_extension('main.v') or { panic(err) }
	mut m := EditorModel2{
		config:          EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:          doc_id
		doc_controller:  c
		lang_syn:        v_syntax
		in_focus:        true
		viewport_height: 20
	}
	m.token_parser.set_syntax(v_syntax)
	c.jump_cursor_to_line(doc_id, u64(y))
	c.jump_cursor_to_line_start(doc_id)
	for _ in 0 .. x {
		c.move_cursor_right(doc_id)
	}
	return m, c, path
}

fn bracket_cursor(m EditorModel2) (int, int) {
	y, x := m.doc_controller.cursor_line_and_x(m.doc_id)
	return int(y), int(x)
}

fn percent(mut m EditorModel2) {
	m.execute_action_normal(ChordAction{
		count:  1
		motion: '%'
	})
}

const bracket_sample = 'fn main() {
	f(a, [1, 2])
}'

fn test_percent_jumps_between_a_bracket_and_its_match() {
	mut m, _, path := bracket_test_editor(bracket_sample, 0, 10)
	defer { os.rm(path) or {} }
	percent(mut m)
	y, x := bracket_cursor(m)
	assert y == 2 && x == 0
	percent(mut m)
	y2, x2 := bracket_cursor(m)
	assert y2 == 0 && x2 == 10
}

fn test_percent_finds_the_first_bracket_after_the_cursor_on_the_line() {
	mut m, _, path := bracket_test_editor(bracket_sample, 1, 4)
	defer { os.rm(path) or {} }
	percent(mut m)
	y, x := bracket_cursor(m)
	assert y == 1 && x == 11, 'the [ after the cursor matches the ]'
}

fn test_percent_skips_brackets_in_strings_and_comments() {
	mut m, _, path := bracket_test_editor("x := '(' + f(a) // )", 0, 0)
	defer { os.rm(path) or {} }
	percent(mut m)
	y, x := bracket_cursor(m)
	assert y == 0 && x == 14
}

fn test_percent_stays_put_without_a_match() {
	for code in ['f(a', 'f( }', 'f ] x', 'f( g()'] {
		mut m, _, path := bracket_test_editor(code, 0, 0)
		defer { os.rm(path) or {} }
		percent(mut m)
		_, x := bracket_cursor(m)
		assert x == 0, code
	}
}

fn test_percent_matches_a_closer_past_a_bracket_left_open() {
	// the } closes the ( left open inside the braces too
	mut m, _, path := bracket_test_editor('{ ( } x', 0, 4)
	defer { os.rm(path) or {} }
	percent(mut m)
	_, x := bracket_cursor(m)
	assert x == 0
	percent(mut m)
	_, x2 := bracket_cursor(m)
	assert x2 == 4

	// and the ( left open has no match
	mut n, _, path2 := bracket_test_editor('{ ( } x', 0, 2)
	defer { os.rm(path2) or {} }
	percent(mut n)
	_, x3 := bracket_cursor(n)
	assert x3 == 2

	// nor does a closer in an interpolation reach out to a bracket around it
	mut o, _, path3 := bracket_test_editor('( "\${ ) }" x', 0, 6)
	defer { os.rm(path3) or {} }
	percent(mut o)
	_, x4 := bracket_cursor(o)
	assert x4 == 6
}

fn test_percent_counts_graphemes_not_runes() {
	// e and a combining acute accent are one grapheme, two runes
	mut m, _, path := bracket_test_editor('é(x)', 0, 0)
	defer { os.rm(path) or {} }
	percent(mut m)
	_, x := bracket_cursor(m)
	assert x == 3
	percent(mut m)
	_, x2 := bracket_cursor(m)
	assert x2 == 1
}

fn test_delete_percent_deletes_through_the_match_either_way() {
	mut m, c, path := bracket_test_editor('a(b c)d', 0, 1)
	defer { os.rm(path) or {} }
	m.execute_action_normal(ChordAction{
		count:    1
		operator: `d`
		motion:   '%'
	})
	assert (c.get_line_bytes(m.doc_id, 0) or { []u8{} }).bytestr() == 'ad'

	mut n, d, path2 := bracket_test_editor('x(\n)y', 1, 0)
	defer { os.rm(path2) or {} }
	n.execute_action_normal(ChordAction{
		count:    1
		operator: `d`
		motion:   '%'
	})
	assert d.line_count(n.doc_id) == 1
	assert (d.get_line_bytes(n.doc_id, 0) or { []u8{} }).bytestr() == 'xy'
}

fn test_percent_extends_a_visual_selection() {
	mut m, _, path := bracket_test_editor(bracket_sample, 0, 10)
	defer { os.rm(path) or {} }
	m.switch_mode_update(SwitchModeMsg{
		mode: .visual
	})
	m.execute_action_visual(ChordAction{
		count:  1
		motion: '%'
	})
	y, x := bracket_cursor(m)
	assert y == 2 && x == 0
	assert m.visual_sel_start_line or { panic('no selection') } == 0
}

fn test_percent_is_a_motion_chord() {
	mut ch := Chord{}
	action := ch.feed('%') or { panic('no action') }
	assert action.motion == '%'
	assert action.operator == none
	ch2_action := fn () ?ChordAction {
		mut ch2 := Chord{}
		ch2.feed('d')
		return ch2.feed('%')
	}() or { panic('no action') }
	assert ch2_action.motion == '%'
	assert ch2_action.operator or { 0 } == `d`
}

fn test_the_bracket_pair_at_the_cursor_is_highlighted() {
	mut m, mut c, path := bracket_test_editor(bracket_sample, 1, 2)
	defer { os.rm(path) or {} }
	pair := m.visible_bracket_pair(m.screen_lines()) or { panic('no pair') }
	assert pair == BracketPair{syntax.Pos{1, 2}, syntax.Pos{1, 12}}

	// in insert mode, the bracket just before the cursor counts too
	c.move_cursor_right(m.doc_id)
	if _ := m.visible_bracket_pair(m.screen_lines()) {
		assert false, 'a highlight off a bracket in normal mode'
	}
	m.switch_mode_update(SwitchModeMsg{
		mode: .insert
	})
	assert m.visible_bracket_pair(m.screen_lines()) or { panic('no pair') } == pair

	m.in_focus = false
	if _ := m.visible_bracket_pair(m.screen_lines()) {
		assert false, 'a highlight in an editor out of focus'
	}
}

fn test_the_highlight_looks_no_further_than_the_view() {
	mut m, _, path := bracket_test_editor(bracket_sample, 0, 10)
	defer { os.rm(path) or {} }
	m.viewport_height = 2
	if _ := m.visible_bracket_pair(m.screen_lines()) {
		assert false, 'matched a closer below the view'
	}
	m.viewport_height = 3
	assert m.visible_bracket_pair(m.screen_lines()) or { panic('no pair') }.close == syntax.Pos{2, 0}
}

fn test_the_highlight_looks_no_further_up_than_the_view() {
	// the cursor on the closer, its opener scrolled out of view above
	mut m, _, path := bracket_test_editor(bracket_sample, 2, 0)
	defer { os.rm(path) or {} }
	m.top_line = 1
	if _ := m.visible_bracket_pair(m.screen_lines()) {
		assert false, 'matched an opener above the view'
	}
	m.top_line = 0
	assert m.visible_bracket_pair(m.screen_lines()) or { panic('no pair') }.open == syntax.Pos{0, 10}

	// `%` still jumps to it
	m.top_line = 1
	percent(mut m)
	y, x := bracket_cursor(m)
	assert y == 0 && x == 10
}

fn test_percent_matches_a_parameter_lists_parens() {
	// a context pushed by a bracket is a bracket node too
	mut m, _, path := bracket_test_editor('fn f(a int) {\n}', 0, 4)
	defer { os.rm(path) or {} }
	percent(mut m)
	_, x := bracket_cursor(m)
	assert x == 10
	percent(mut m)
	_, x2 := bracket_cursor(m)
	assert x2 == 4
}

fn test_percent_jumps_between_an_interpolations_braces() {
	// `x := 'a${b}c'`: `{` at col 8, `}` at col 10
	mut m, _, path := bracket_test_editor("x := 'a\${b}c'", 0, 8)
	defer { os.rm(path) or {} }
	percent(mut m)
	mut y, mut x := bracket_cursor(m)
	assert y == 0 && x == 10
	percent(mut m)
	y, x = bracket_cursor(m)
	assert y == 0 && x == 8
}

fn test_without_a_syntax_brackets_are_matched_by_counting() {
	mut m, _, path := bracket_test_editor('a (b [c (d\ne) f)', 0, 2)
	defer { os.rm(path) or {} }
	m.lang_syn = syntax.noop_syntax
	// counting `(` and `)` only, as Vim does: the `[` doesn't get in the way
	percent(mut m)
	mut y, mut x := bracket_cursor(m)
	assert y == 1 && x == 4
	percent(mut m)
	y, x = bracket_cursor(m)
	assert y == 0 && x == 2

	// and the pair under the cursor is highlighted
	assert m.visible_bracket_pair(m.screen_lines()) or { panic('no pair') } == BracketPair{syntax.Pos{0, 2}, syntax.Pos{1, 4}}

	// a bracket without a match has none
	mut u, _, upath := bracket_test_editor('a [b', 0, 2)
	defer { os.rm(upath) or {} }
	u.lang_syn = syntax.noop_syntax
	percent(mut u)
	y, x = bracket_cursor(u)
	assert y == 0 && x == 2
}

fn bracket_keys(mut m EditorModel2, keys string) {
	for k in keys.runes() {
		m.normal_mode_update(tea.KeyMsg{
			k_type: .runes
			runes:  [k]
		})
	}
}

fn test_a_count_takes_percent_that_far_down_the_file() {
	mut lines := []string{}
	for i in 0 .. 10 {
		lines << '\t(line ${i})'
	}
	mut m, _, path := bracket_test_editor(lines.join('\n'), 0, 1)
	defer { os.rm(path) or {} }
	// to the first non-blank of the line, as in Vim
	for keys, want in {
		'50%':  4
		'100%': 9
		'1%':   0
		'35%':  3
	} {
		bracket_keys(mut m, keys)
		y, x := bracket_cursor(m)
		assert y == want && x == 1, keys
	}
	// over 100 stays put, and without a count it's still a bracket jump
	bracket_keys(mut m, '101%')
	mut y, mut x := bracket_cursor(m)
	assert y == 3 && x == 1
	bracket_keys(mut m, '%')
	y, x = bracket_cursor(m)
	assert y == 3 && x == 8
}
