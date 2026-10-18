module main

import os
import bobatea as tea
import time
import lib.cfg
import lib.documents
import lib.syntax

const fold_sample = 'fn main() {
	if x {
		a()
	} else {
		b()
	}
	f(a, [
		1,
	])
}
fn other() {
	c()
}'

// fold_test_editor opens `content` as a V file, with the cursor `x`
// graphemes into line `y`
fn fold_test_editor(content string, y int, x int) (EditorModel, &documents.Controller, string) {
	path := os.join_path(os.temp_dir(), 'lilly_folds_${time.now().unix_nano()}.v')
	os.write_file(path, content) or { panic('failed to write temp file: ${err}') }
	mut c := &documents.Controller{}
	doc_id := c.open_document(path) or { panic('failed to open temp document: ${err}') }
	v_syntax := syntax.resolve_from_extension('main.v') or { panic(err) }
	mut m := EditorModel{
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

fn fold_keys(mut m EditorModel, keys string) {
	for k in keys.runes() {
		m.normal_mode_update(tea.KeyMsg{
			k_type: .runes
			runes:  [k]
		})
	}
}

fn fold_cursor(m EditorModel) (int, int) {
	y, x := m.doc_controller.cursor_line_and_x(m.doc_id)
	return int(y), int(x)
}

fn test_folds_are_the_blocks_that_span_lines() {
	mut m, _, path := fold_test_editor(fold_sample, 0, 0)
	defer { os.rm(path) or {} }
	// the function and its body are one fold. The if block ends a line
	// early, so closing it leaves `} else {` showing.
	assert m.folds_at(2) == [Fold{0, 9}, Fold{1, 2}]
	assert m.folds_at(4) == [Fold{0, 9}, Fold{3, 5}]
	// the call's brackets and the array's are one fold too
	assert m.folds_at(7) == [Fold{0, 9}, Fold{6, 8}]
	assert m.folds_at(10) == [Fold{10, 12}]
	assert m.folds_in(0, 12) == [Fold{0, 9}, Fold{1, 2}, Fold{3, 5}, Fold{6, 8}, Fold{10, 12}]
}

fn test_zc_closes_the_innermost_fold_and_zo_opens_one() {
	mut m, _, path := fold_test_editor(fold_sample, 2, 2)
	defer { os.rm(path) or {} }
	fold_keys(mut m, 'zc')
	assert m.closed_folds == [Fold{1, 2}]
	y, _ := fold_cursor(m)
	assert y == 1, 'the cursor goes to the start of the fold'
	assert m.screen_lines() == [0, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]

	// on a closed fold, zc closes the one around it
	fold_keys(mut m, 'zc')
	assert m.closed_folds == [Fold{0, 9}, Fold{1, 2}]
	assert m.screen_lines() == [0, 10, 11, 12]
	y2, _ := fold_cursor(m)
	assert y2 == 0

	// zo opens one, and the one inside stays closed
	fold_keys(mut m, 'zo')
	assert m.closed_folds == [Fold{1, 2}]
	assert m.screen_lines() == [0, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]

	fold_keys(mut m, 'zR')
	assert m.closed_folds.len == 0
}

fn test_za_toggles_and_zm_closes_every_fold() {
	mut m, _, path := fold_test_editor(fold_sample, 4, 2)
	defer { os.rm(path) or {} }
	fold_keys(mut m, 'za')
	assert m.closed_folds == [Fold{3, 5}]
	fold_keys(mut m, 'za')
	assert m.closed_folds.len == 0

	// zC closes every fold around the cursor, zO opens them all again
	fold_keys(mut m, 'jzC')
	assert m.closed_folds == [Fold{0, 9}, Fold{3, 5}]
	fold_keys(mut m, 'zO')
	assert m.closed_folds.len == 0

	fold_keys(mut m, 'zM')
	assert m.screen_lines() == [0, 10]
	y, _ := fold_cursor(m)
	assert y == 0, 'the cursor goes to the start of the outermost fold'
	// the folds inside are closed too, as zo shows
	fold_keys(mut m, 'zo')
	assert m.screen_lines() == [0, 1, 3, 6, 9, 10]
	fold_keys(mut m, 'zM')
	// zA on a closed fold opens it and every fold inside
	fold_keys(mut m, 'zA')
	assert m.closed_folds == [Fold{10, 12}]
}

fn test_j_and_k_step_over_a_closed_fold() {
	mut m, _, path := fold_test_editor(fold_sample, 6, 1)
	defer { os.rm(path) or {} }
	fold_keys(mut m, 'zc')
	assert m.closed_folds == [Fold{6, 8}]
	fold_keys(mut m, 'k')
	y, _ := fold_cursor(m)
	assert y == 5
	fold_keys(mut m, 'jj')
	y2, x2 := fold_cursor(m)
	assert y2 == 9, 'the fold is one line to j'
	assert x2 == 0
	fold_keys(mut m, 'k')
	y3, x3 := fold_cursor(m)
	assert y3 == 6
	assert x3 == 1, 'the column is kept'
	fold_keys(mut m, '3k')
	y4, _ := fold_cursor(m)
	assert y4 == 3
	fold_keys(mut m, '3j')
	y5, _ := fold_cursor(m)
	assert y5 == 6
	assert m.closed_folds == [Fold{6, 8}], 'stepping over it leaves it closed'

	m.normal_mode_update(tea.KeyMsg{
		k_type: .special
		runes:  'down'.runes()
	})
	y6, _ := fold_cursor(m)
	assert y6 == 9, 'and so do the arrow keys'
}

fn test_moving_into_a_closed_fold_opens_it() {
	mut m, mut c, path := fold_test_editor(fold_sample, 2, 2)
	defer { os.rm(path) or {} }
	fold_keys(mut m, 'zczc')
	assert m.closed_folds == [Fold{0, 9}, Fold{1, 2}]
	// G is the last line, outside the folds
	fold_keys(mut m, 'G')
	assert m.closed_folds.len == 2
	// a jump into both opens both
	c.jump_cursor_to_line(m.doc_id, 2)
	m.scroll_to_cursor()
	assert m.closed_folds.len == 0

	// one starting on the cursor's line shows it, so it stays closed
	fold_keys(mut m, 'zc')
	assert m.closed_folds == [Fold{1, 2}]
	fold_keys(mut m, 'l')
	assert m.closed_folds == [Fold{1, 2}]
}

fn test_dd_on_a_closed_fold_deletes_all_of_it() {
	mut m, mut c, path := fold_test_editor(fold_sample, 7, 2)
	defer { os.rm(path) or {} }
	fold_keys(mut m, 'zc')
	assert m.closed_folds == [Fold{6, 8}]
	fold_keys(mut m, 'dd')
	assert c.line_count(m.doc_id) == 10
	assert (c.get_line_bytes(m.doc_id, 6) or { panic('no line') }).bytestr() == '}'
	assert m.closed_folds.len == 0

	// as is a line selection on one
	c.undo(m.doc_id)
	c.jump_cursor_to_line(m.doc_id, 7)
	fold_keys(mut m, 'zc')
	assert m.closed_folds == [Fold{6, 8}]
	m.switch_mode_update(SwitchModeMsg{
		mode: .visual_line
	})
	m.execute_action_visual(ChordAction{
		count:    1
		operator: `d`
	})
	assert c.line_count(m.doc_id) == 10
}

fn test_edits_move_closed_folds() {
	mut m, mut c, path := fold_test_editor(fold_sample, 11, 1)
	defer { os.rm(path) or {} }
	fold_keys(mut m, 'zc')
	assert m.closed_folds == [Fold{10, 12}]

	// a line added above, as another split showing the file would
	c.jump_cursor_to_line(m.doc_id, 0)
	c.jump_cursor_to_line_start(m.doc_id)
	c.insert_string(m.doc_id, '// top\n')
	m.sync_folds()
	assert m.closed_folds == [Fold{11, 13}]

	// and one taken away
	c.delete_line(m.doc_id, 0)
	m.sync_folds()
	assert m.closed_folds == [Fold{10, 12}]

	// a fold around an edit grows with it
	c.jump_cursor_to_line(m.doc_id, 0)
	fold_keys(mut m, 'zc')
	assert m.closed_folds == [Fold{0, 9}, Fold{10, 12}]
	c.jump_cursor_to_line(m.doc_id, 4)
	c.jump_cursor_to_line_end(m.doc_id)
	c.insert_string(m.doc_id, '\n\t\tz()')
	m.sync_folds()
	assert m.closed_folds == [Fold{0, 10}, Fold{11, 13}]

	// and one an edit reaches into opens
	c.delete_line(m.doc_id, 12)
	m.sync_folds()
	assert m.closed_folds == [Fold{0, 10}]
}

fn test_the_view_scrolls_by_rows() {
	mut m, _, path := fold_test_editor(fold_sample, 0, 0)
	defer { os.rm(path) or {} }
	m.viewport_height = 3
	fold_keys(mut m, 'zc')
	assert m.closed_folds == [Fold{0, 9}]
	fold_keys(mut m, 'jj')
	y, _ := fold_cursor(m)
	assert y == 11
	assert m.top_line == 0, 'rows 0, 10 and 11 fill the view'
	fold_keys(mut m, 'j')
	assert m.top_line == 10
	assert m.screen_lines() == [10, 11, 12]
	fold_keys(mut m, 'kkk')
	assert m.top_line == 0

	// the view stops where the last line is on the bottom row
	m.top_line = 12
	m.scroll_to_cursor()
	assert m.top_line == 0
	m.top_line = 11
	fold_keys(mut m, 'G')
	assert m.top_line == 10
}

fn fold_visual_keys(mut m EditorModel, keys string) {
	for k in keys.runes() {
		m.visual_mode_update(tea.KeyMsg{
			k_type: .runes
			runes:  [k]
		})
	}
}

fn test_zo_puts_the_cursor_back_where_zc_found_it() {
	mut m, _, path := fold_test_editor(fold_sample, 2, 2)
	defer { os.rm(path) or {} }
	fold_keys(mut m, 'zc')
	y, _ := fold_cursor(m)
	assert y == 1
	fold_keys(mut m, 'zo')
	y2, x2 := fold_cursor(m)
	assert y2 == 2
	assert x2 == 2

	// it shows on the inner fold until that opens too
	fold_keys(mut m, 'zczc')
	y3, _ := fold_cursor(m)
	assert y3 == 0
	fold_keys(mut m, 'zo')
	y4, _ := fold_cursor(m)
	assert y4 == 1
	fold_keys(mut m, 'zo')
	y5, x5 := fold_cursor(m)
	assert y5 == 2
	assert x5 == 2

	// and zR opens every fold zM closed around it
	fold_keys(mut m, 'zM')
	y6, _ := fold_cursor(m)
	assert y6 == 0
	fold_keys(mut m, 'zR')
	y7, x7 := fold_cursor(m)
	assert y7 == 2
	assert x7 == 2

	// a move after the close forgets where it was
	fold_keys(mut m, 'zcl')
	y8, x8 := fold_cursor(m)
	assert y8 == 1
	fold_keys(mut m, 'zo')
	y9, x9 := fold_cursor(m)
	assert y9 == 1
	assert x9 == x8
}

fn test_zj_and_zk_move_between_folds() {
	mut m, _, path := fold_test_editor(fold_sample, 0, 0)
	defer { os.rm(path) or {} }
	// zj goes to the start of the next fold down
	mut starts := []int{}
	for _ in 0 .. 5 {
		fold_keys(mut m, 'zj')
		y, _ := fold_cursor(m)
		starts << y
	}
	assert starts == [1, 3, 6, 10, 10]
	// zk to the end of the next one up
	mut ends := []int{}
	for _ in 0 .. 5 {
		fold_keys(mut m, 'zk')
		y, _ := fold_cursor(m)
		ends << y
	}
	assert ends == [9, 8, 5, 2, 2]

	// a count goes that many folds
	fold_keys(mut m, 'gg2zj')
	y, _ := fold_cursor(m)
	assert y == 3

	// a closed fold is one fold, so zj skips the ones inside it, and zk
	// stops on it
	fold_keys(mut m, 'zjzc')
	assert m.closed_folds == [Fold{6, 8}]
	fold_keys(mut m, 'kzj')
	y2, _ := fold_cursor(m)
	assert y2 == 6
	fold_keys(mut m, 'zj')
	y3, _ := fold_cursor(m)
	assert y3 == 10
	fold_keys(mut m, 'zkzk')
	y4, _ := fold_cursor(m)
	assert y4 == 6
	assert m.closed_folds == [Fold{6, 8}]
	// and from a closed fold, zj goes past the folds inside it
	fold_keys(mut m, 'ggzczj')
	y5, _ := fold_cursor(m)
	assert y5 == 10
}

fn test_fold_commands_act_on_each_row_of_a_selection() {
	mut m, _, path := fold_test_editor(fold_sample, 1, 0)
	defer { os.rm(path) or {} }
	m.switch_mode_update(SwitchModeMsg{
		mode: .visual_line
	})
	fold_visual_keys(mut m, '3jzc')
	// each row's innermost fold, not the one around them all
	assert m.closed_folds == [Fold{1, 2}, Fold{3, 5}]
	y, _ := fold_cursor(m)
	assert y == 3, 'the cursor goes to the start of the fold it was hidden in'

	m.switch_mode_update(SwitchModeMsg{
		mode: .visual_line
	})
	fold_visual_keys(mut m, 'kzo')
	assert m.closed_folds.len == 0

	m.switch_mode_update(SwitchModeMsg{
		mode: .visual_line
	})
	fold_visual_keys(mut m, 'jjjzC')
	// every fold around each row, but none below the selection
	assert m.closed_folds == [Fold{0, 9}, Fold{1, 2}, Fold{3, 5}]

	// zA on the closed fold opens it and every fold inside
	m.switch_mode_update(SwitchModeMsg{
		mode: .visual_line
	})
	fold_visual_keys(mut m, 'zA')
	assert m.closed_folds.len == 0
}

fn test_dj_and_dk_take_in_a_closed_fold() {
	mut m, mut c, path := fold_test_editor(fold_sample, 6, 0)
	defer { os.rm(path) or {} }
	fold_keys(mut m, 'zck')
	assert m.closed_folds == [Fold{6, 8}]
	fold_keys(mut m, 'dj')
	// lines 5 to 8: the line and all of the fold below it
	assert c.line_count(m.doc_id) == 9
	assert (c.get_line_bytes(m.doc_id, 5) or { panic('no line') }).bytestr() == '}'
	y, _ := fold_cursor(m)
	assert y == 5

	c.undo(m.doc_id)
	c.jump_cursor_to_line(m.doc_id, 6)
	fold_keys(mut m, 'zcj')
	y2, _ := fold_cursor(m)
	assert y2 == 9
	fold_keys(mut m, 'dk')
	// lines 6 to 9: all of the fold, and the line below it
	assert c.line_count(m.doc_id) == 9
	assert (c.get_line_bytes(m.doc_id, 6) or { panic('no line') }).bytestr() == 'fn other() {'

	// with nowhere to go, dj deletes nothing
	fold_keys(mut m, 'Gdj')
	assert c.line_count(m.doc_id) == 9
}

fn test_o_on_a_closed_fold_opens_a_line_below_it() {
	mut m, mut c, path := fold_test_editor(fold_sample, 1, 0)
	defer { os.rm(path) or {} }
	fold_keys(mut m, 'zczc')
	assert m.closed_folds == [Fold{0, 9}, Fold{1, 2}]
	fold_keys(mut m, 'o')
	assert c.line_count(m.doc_id) == 14
	y, _ := fold_cursor(m)
	assert y == 10
	assert (c.get_line_bytes(m.doc_id, 9) or { panic('no line') }).bytestr() == '}'
	assert m.closed_folds == [Fold{0, 9}, Fold{1, 2}], 'the folds stay closed'
	m.sync_folds()
	assert m.closed_folds == [Fold{0, 9}, Fold{1, 2}]
}

fn test_zj_and_zk_reach_folds_far_away() {
	// the folds are further apart than the first window searched
	content := 'fn a() {\n\tx()\n}\n' + '\n'.repeat(300) + 'fn b() {\n\tx()\n}'
	mut m, _, path := fold_test_editor(content, 0, 0)
	defer { os.rm(path) or {} }
	fold_keys(mut m, 'zj')
	y, _ := fold_cursor(m)
	assert y == 303
	fold_keys(mut m, 'zj')
	y2, _ := fold_cursor(m)
	assert y2 == 303, 'there is no fold below'
	fold_keys(mut m, 'zk')
	y3, _ := fold_cursor(m)
	assert y3 == 2
	fold_keys(mut m, 'zk')
	y4, _ := fold_cursor(m)
	assert y4 == 2, 'there is no fold above'
}

// fold_functions is `n` three line functions, one after another
fn fold_functions(n int) string {
	mut lines := []string{}
	for i in 0 .. n {
		lines << 'fn f${i}() {'
		lines << '\tx()'
		lines << '}'
	}
	return lines.join('\n')
}

fn test_zm_closes_folds_as_their_lines_come_into_reach() {
	mut m, _, path := fold_test_editor(fold_functions(100), 0, 0)
	defer { os.rm(path) or {} }
	m.viewport_height = 10
	fold_keys(mut m, 'zM')
	// only the folds around the view close straight away
	assert m.closed_folds.len > 0
	assert m.closed_folds.len < 100
	assert m.screen_lines() == [0, 3, 6, 9, 12, 15, 18, 21, 24, 27]

	// and the rest as moves reach them, so each is still one row
	fold_keys(mut m, '50j')
	y, _ := fold_cursor(m)
	assert y == 150
	m.scroll_to_cursor()
	assert m.screen_lines().all(it % 3 == 0)
	fold_keys(mut m, '50k')
	y2, _ := fold_cursor(m)
	assert y2 == 0

	// zR opens them all and stops closing more
	fold_keys(mut m, 'zR')
	assert m.closed_folds.len == 0
	fold_keys(mut m, '50j')
	assert m.closed_folds.len == 0
}

fn test_a_fold_opened_after_zm_stays_open() {
	mut m, _, path := fold_test_editor(fold_functions(100), 0, 0)
	defer { os.rm(path) or {} }
	m.viewport_height = 10
	fold_keys(mut m, 'zMzo')
	assert m.closed_fold_at(0) == none
	// far away and back again
	fold_keys(mut m, 'G')
	m.scroll_to_cursor()
	fold_keys(mut m, 'gg')
	m.scroll_to_cursor()
	assert m.closed_fold_at(0) == none
	assert m.closed_fold_at(3) or { panic('not closed') } == Fold{3, 5}

	// a jump into the middle of a fold not yet reached opens it, and it
	// stays open as the lines either side come into reach
	m.doc_controller.jump_cursor_to_line(m.doc_id, 151)
	m.scroll_to_cursor()
	assert m.closed_fold_at(151) == none
	fold_keys(mut m, 'kk')
	y, _ := fold_cursor(m)
	assert y == 147, 'the row above is the line the fold starts on, then the fold above'
	assert m.closed_fold_at(150) == none
}

fn test_the_lines_zm_reached_move_with_edits() {
	mut m, mut c, path := fold_test_editor(fold_functions(100), 0, 0)
	defer { os.rm(path) or {} }
	m.viewport_height = 10
	fold_keys(mut m, 'zMzo')
	// a line added above, as another split showing the file would
	c.insert_string(m.doc_id, '// top\n')
	m.sync_folds()
	// the fold opened moves down with its lines, and stays open
	assert m.closed_fold_at(1) == none
	assert m.closed_fold_at(4) or { panic('not closed') } == Fold{4, 6}
	c.jump_cursor_to_line(m.doc_id, 4)
	fold_keys(mut m, '40j')
	y, _ := fold_cursor(m)
	assert y == 124
}

fn test_zm_again_closes_folds_opened_since() {
	mut m, _, path := fold_test_editor(fold_functions(100), 0, 0)
	defer { os.rm(path) or {} }
	m.viewport_height = 10
	fold_keys(mut m, 'zMzo')
	assert m.closed_fold_at(0) == none
	fold_keys(mut m, 'zM')
	assert m.closed_fold_at(0) or { panic('not closed') } == Fold{0, 2}
}

fn test_a_jump_after_zm_scrolls_over_the_folds_above_the_cursor() {
	mut m, mut c, path := fold_test_editor(fold_functions(100), 0, 0)
	defer { os.rm(path) or {} }
	m.viewport_height = 10
	fold_keys(mut m, 'zM')
	c.jump_cursor_to_line(m.doc_id, 150)
	m.scroll_to_cursor()
	// nine folds above it, one row each, put the cursor on the bottom row
	assert m.top_line == 123
	assert m.screen_lines().last() == 150
}

fn test_zk_after_zm_stops_on_a_fold_not_yet_reached() {
	content := 'fn a() {\n\tx()\n}\n' + '\n'.repeat(198) + 'fn b() {\n\tx()\n}\n' + '\n'.repeat(198)
	mut m, _, path := fold_test_editor(content, 400, 0)
	defer { os.rm(path) or {} }
	m.viewport_height = 10
	fold_keys(mut m, 'zMzk')
	y, _ := fold_cursor(m)
	assert y == 201, 'on the closed fold, not inside it'
	assert m.closed_fold_at(201) or { panic('not closed') } == Fold{201, 203}
}

fn test_lines_reached_at_the_end_of_a_range_move_with_edits() {
	mut m, mut c, path := fold_test_editor(fold_functions(100), 0, 0)
	defer { os.rm(path) or {} }
	m.viewport_height = 10
	fold_keys(mut m, 'zM')
	// open the last fold zM reached
	last := m.fold_reach[0].last
	f := m.closed_fold_at(last) or { panic('not closed') }
	m.set_closed_folds(m.closed_folds.filter(it != f))
	// three lines added above, so the fold's lines move down past where
	// the reached lines ended
	c.insert_string(m.doc_id, '// a\n// b\n// c\n')
	m.sync_folds()
	c.jump_cursor_to_line(m.doc_id, u64(f.start + 3))
	m.scroll_to_cursor()
	assert m.closed_fold_at(f.start + 3) == none, 'it stays open'
}

fn test_folds_in_a_few_lines_agree_with_those_in_all_of_them() {
	// the comment opening on the line the block closes on leaves that line
	// showing, whether or not it's among the lines asked about
	mut m, _, path := fold_test_editor('fn a() {\n\tx()\n}/*\ny', 0, 0)
	defer { os.rm(path) or {} }
	assert m.folds_in(0, 0) == [Fold{0, 1}]
	assert m.folds_in(0, 3) == [Fold{0, 1}]
}

// wrapped is `n` if blocks, three lines each, inside one function
fn wrapped(n int) string {
	mut lines := ['fn main() {']
	for _ in 0 .. n {
		lines << '\tif x {'
		lines << '\t\ty()'
		lines << '\t}'
	}
	lines << '}'
	return lines.join('\n')
}

fn test_zm_closes_the_folds_inside_a_closed_one_only_as_it_opens() {
	mut m, _, path := fold_test_editor(wrapped(300), 0, 0)
	defer { os.rm(path) or {} }
	m.viewport_height = 10
	fold_keys(mut m, 'zM')
	assert m.screen_lines() == [0]
	// the 300 inside it wait to be shown
	assert m.closed_folds == [Fold{0, 901}]
	fold_keys(mut m, 'zo')
	assert m.screen_lines() == [0, 1, 4, 7, 10, 13, 16, 19, 22, 25]
	assert m.closed_folds.len < 20
}

fn test_za_after_zm_opens_the_folds_inside_for_good() {
	mut m, _, path := fold_test_editor(wrapped(300), 0, 0)
	defer { os.rm(path) or {} }
	m.viewport_height = 10
	fold_keys(mut m, 'zMzA')
	assert m.screen_lines() == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	fold_keys(mut m, '50j')
	assert m.closed_folds.len == 0
}

fn test_zm_survives_the_view_ending_up_past_the_last_line() {
	// an array long enough to fill the view, after the functions
	mut lines := [fold_functions(40), 'x := [']
	for _ in 0 .. 60 {
		lines << '\t1,'
	}
	lines << ']'
	mut m, _, path := fold_test_editor(lines.join('\n'), 0, 0)
	defer { os.rm(path) or {} }
	m.viewport_height = 20
	fold_keys(mut m, 'zMG')
	assert m.top_line > 100
	// deleting the array takes the lines the view was showing
	fold_keys(mut m, 'd%')
	line_count := int(m.doc_controller.line_count(m.doc_id))
	assert line_count < 125
	assert m.top_line < line_count
	y, _ := fold_cursor(m)
	assert y in m.screen_lines()
}
