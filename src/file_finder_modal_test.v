module main

import time
import lib.draw

struct TestDrawer {}

fn (mut drawer TestDrawer) draw_text(x int, y int, text string) {
	time.sleep(1 * time.millisecond)
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

fn test_current_selection_gets_zeros_on_search_term_amend() {
	mut mock_modal := FileFinderModal{
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

fn test_resolve_file_paths_returns_realistic_results() {
	mut mock_modal := FileFinderModal{
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

fn test_fuzzy_searching_is_operational() {
	mut mock_modal := FileFinderModal{
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
