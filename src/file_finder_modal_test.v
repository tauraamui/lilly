module main

import time
import arrays
import lib.draw

struct TestDrawer {
	draw_text_callback fn (x int, y int, text string)
}

fn (mut drawer TestDrawer) draw_text(x int, y int, text string) {
	if drawer.draw_text_callback == unsafe { nil } { return }
	drawer.draw_text_callback(x, y, text)
}

fn (mut drawer TestDrawer) write(text string) {
	time.sleep(1 * time.millisecond)
}

fn (mut drawer TestDrawer) draw_rect(x int, y int, width int, height int) {
	time.sleep(1 * time.millisecond)
}

fn (mut drawer TestDrawer) draw_point(x int, y int) {
	time.sleep(1 * time.millisecond)
}

fn (mut drawer TestDrawer) set_color(c draw.Color) {}
fn (mut drawer TestDrawer) set_bg_color(c draw.Color) {}
fn (mut drawer TestDrawer) reset_color() {}
fn (mut drawer TestDrawer) reset_bg_color() {}
fn (mut drawer TestDrawer) rate_limit_draws() bool { return false }
fn (mut drawer TestDrawer) window_width() int { return 500 }
fn (mut drawer TestDrawer) window_height() int { return 500 }
fn (mut drawer TestDrawer) set_cursor_position(x int, y int) {}
fn (mut drawer TestDrawer) bold() {}
fn (mut drawer TestDrawer) reset() {}
fn (mut drawer TestDrawer) clear() {}
fn (mut drawer TestDrawer) flush() {}

fn test_on_search_term_adjust_list_order_changes() {
	mut drawn_text := []string{}
	mut ref := &drawn_text

	mut mock_drawer := TestDrawer{
		draw_text_callback: fn [mut ref] (x int, y int, text string) { ref << text }
	}

	mut mock_modal := FileFinderModal{
		file_path: "**tfm**"
		file_paths: [
			'./src/project/main.v',
			'./src/project/lib/some_utilities.v',
			'./src/project/lib/meta.v',
			'./src/project/lib/database/connection.v',
		]
	}

	mock_modal.draw(mut mock_drawer)

	assert drawn_text.len > 0
	mut cleaned_list := drawn_text[1..drawn_text.len - 2]
	assert cleaned_list == [
		"./src/project/main.v",
		"./src/project/lib/some_utilities.v",
		"./src/project/lib/meta.v",
		"./src/project/lib/database/connection.v"
	]

	mock_modal.on_key_down(draw.Event{ utf8: "c" }, mut Editor{})
	mock_modal.on_key_down(draw.Event{ utf8: "o" }, mut Editor{})
	mock_modal.on_key_down(draw.Event{ utf8: "n" }, mut Editor{})

	drawn_text.clear()
	mock_modal.draw(mut mock_drawer)
	assert drawn_text.len > 0
	cleaned_list = drawn_text[1..drawn_text.len - 2]
	assert cleaned_list == [
		"./src/project/lib/database/connection.v"
		"./src/project/main.v",
		"./src/project/lib/some_utilities.v",
		"./src/project/lib/meta.v"
	]
}

fn test_current_selection_gets_zeros_on_search_term_amend() {
	mut mock_modal := FileFinderModal{
		file_path: "**tfm**"
		file_paths: [
			'./src/project/main.v',
			'./src/project/lib/some_utilities.v',
		]
	}

	assert mock_modal.current_selection == 0
	mock_modal.on_key_down(draw.Event{utf8: "d"}, mut Editor{})
	assert mock_modal.current_selection == 0

	mock_modal.on_key_down(draw.Event{code: .down}, mut Editor{})
	assert mock_modal.current_selection == 1

	mock_modal.on_key_down(draw.Event{utf8: "r"}, mut Editor{})
	assert mock_modal.current_selection == 0
}

/*
fn test_resolve_file_paths_returns_realistic_results() {
	mut mock_modal := FileFinderModal{
		file_path: "**tfm**"
		file_paths: [
			'./src/project/main.v',
			'./src/project/lib/some_utilities.v',
		]
	}

	mock_modal.search.query = 'some'
	assert mock_modal.resolve_file_paths().map(it.content) == [
		'./src/project/lib/some_utilities.v',
		'./src/project/main.v',
	]

	mock_modal.search.query = 'mai'
	assert mock_modal.resolve_file_paths().map(it.content) == [
		'./src/project/main.v',
		'./src/project/lib/some_utilities.v',
	]

	mock_modal.search.query = 'proj'
	assert mock_modal.resolve_file_paths().map(it.content) == [
		'./src/project/main.v',
		'./src/project/lib/some_utilities.v',
	]

	mock_modal.search.query = ''
	assert mock_modal.resolve_file_paths().map(it.content) == [
		'./src/project/main.v',
		'./src/project/lib/some_utilities.v',
	]

	mock_modal.search.query = 'zkf'
	assert mock_modal.resolve_file_paths().map(it.content) == [
		'./src/project/lib/some_utilities.v',
		'./src/project/main.v',
	]
}
*/

fn test_score_values_by_query_success() {
	mut paths := [
			'./src/project/main.v',
			'./src/project/lib/some_utilities.v',
			'./src/project/lib/meta.v',
			'./src/project/lib/database/connection.v',
		]

	mut scores := []f32{ len: paths.len }
	paths.sort_with_compare(fn (a &string, b &string) int {
		a_score := score_value_by_query("conn", a)
		b_score := score_value_by_query("conn", b)
		if a_score < b_score { return 1}
		if b_score > a_score { return - 1 }
		return 0
	})

	assert paths == [
		'./src/project/lib/database/connection.v',
		'./src/project/main.v',
		'./src/project/lib/some_utilities.v',
		'./src/project/lib/meta.v',
	]
}

/*
fn test_fuzzy_searching_is_operational() {
	mut mock_modal := FileFinderModal{
		file_path: "**tfm**"
		file_paths: [
			'./src/project/main.v',
			'./src/project/lib/some_utilities.v',
		]
	}

	mock_modal.search.query = 'ut'
	assert mock_modal.resolve_file_paths().map(it.content) == [
		'./src/project/lib/some_utilities.v',
		'./src/project/main.v',
	]
}
*/
