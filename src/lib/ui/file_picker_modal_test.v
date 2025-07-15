// Copyright 2024 The Lilly Editor contributors
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

module ui

import time
import lib.draw
import lib.theme as themelib

struct TestDrawer {
	draw_text_callback fn (x int, y int, text string)           @[required]
	draw_rect_callback fn (x int, y int, width int, height int) @[required]
}

fn (drawer TestDrawer) theme() themelib.Theme {
	return themelib.Theme.new('test') or { panic('error occurred loading theme: ${err}') }
}

fn (mut drawer TestDrawer) draw_text(x int, y int, text string) {
	if drawer.draw_text_callback == unsafe { nil } {
		return
	}
	drawer.draw_text_callback(x, y, text)
}

fn (mut drawer TestDrawer) write(text string) {
	time.sleep(1 * time.millisecond)
}

fn (mut drawer TestDrawer) draw_rect(x int, y int, width int, height int) {
	if drawer.draw_rect_callback == unsafe { nil } {
		return
	}
	drawer.draw_rect_callback(x, y, width, height)
}

fn (mut drawer TestDrawer) draw_point(x int, y int) {
	time.sleep(1 * time.millisecond)
}

fn (mut drawer TestDrawer) render_debug() bool {
	return false
}

fn (mut drawer TestDrawer) set_color(c draw.Color) {}

fn (mut drawer TestDrawer) set_bg_color(c draw.Color) {}

fn (mut drawer TestDrawer) reset_color() {}

fn (mut drawer TestDrawer) reset_bg_color() {}

fn (mut drawer TestDrawer) rate_limit_draws() bool {
	return false
}

fn (mut drawer TestDrawer) window_width() int {
	return 500
}

fn (mut drawer TestDrawer) window_height() int {
	return 500
}

fn (mut drawer TestDrawer) set_cursor_position(x int, y int) {}

fn (mut drawer TestDrawer) set_cursor_to_block() {}

fn (mut drawer TestDrawer) set_cursor_to_underline() {}

fn (mut drawer TestDrawer) set_cursor_to_vertical_bar() {}

fn (mut drawer TestDrawer) show_cursor() {}

fn (mut drawer TestDrawer) hide_cursor() {}

fn (mut drawer TestDrawer) bold() {}

fn (mut drawer TestDrawer) set_style(s draw.Style) {}

fn (mut drawer TestDrawer) clear_style() {}

fn (mut drawer TestDrawer) reset() {}

fn (mut drawer TestDrawer) clear() {}

fn (mut drawer TestDrawer) flush() {}

fn test_scoring_by_query() {
	score_a := score_value_by_query('filefinderpath', '/lilly/src/src.dsym/contents/resources/dwarf/src')
	score_b := score_value_by_query('filefinderpath', '/lilly/src/file_finder_modal_test.v')

	assert score_a < score_b
}

@[assert_continues]
fn test_direct_sort_with_compare_on_array() {
	mut query := 'lillybanner'
	mut broken_file_paths := [
		'./LICENSE',
		'./v.mod',
		'./README.md',
		'./debug.log',
		'./experiment/more-length/RobotoMono-Regular.ttf',
		'./docs/lilly-banner.png',
		'./experiment/main.v',
		'./lilly.dSYM/Contents/Resources/DWARF/lilly',
	]

	broken_file_paths.sort_with_compare(fn [query] (a &string, b &string) int {
		a_score := score_value_by_query(query, a)
		b_score := score_value_by_query(query, b)
		if b_score > a_score {
			return 1
		}
		if a_score == b_score {
			return 0
		}
		return -1
	})

	assert broken_file_paths[0] == './docs/lilly-banner.png'

	query = 'utili'
	mut working_file_paths := [
		'./src/project/main.v',
		'./src/project/lib/some_utilities.v',
		'./src/project/LIB/META.v',
		'./src/project/lib/database/connection.v',
		'./lilly.dSYM/Contents/Resources/DWARF/lilly',
		'efijwifweifewf',
		'somethingelse',
		'onelastthing',
	]

	working_file_paths.sort_with_compare(fn [query] (a &string, b &string) int {
		a_score := score_value_by_query(query, a)
		b_score := score_value_by_query(query, b)
		if b_score > a_score {
			return 1
		}
		if a_score == b_score {
			return 0
		}
		return -1
	})

	assert working_file_paths[0] == './src/project/lib/some_utilities.v'
}

struct DrawnRect {
	x      int
	y      int
	width  int
	height int
}

fn test_on_search_term_adjust_list_order_changes() {
	mut drawn_text := []string{}
	mut drawn_text_ref := &drawn_text

	mut drawn_rects := []DrawnRect{}
	mut drawn_rects_ref := &drawn_rects

	mut mock_drawer := TestDrawer{
		draw_text_callback: fn [mut drawn_text_ref] (x int, y int, text string) {
			drawn_text_ref << text
		}
		draw_rect_callback: fn [mut drawn_rects_ref] (x int, y int, width int, height int) {
			drawn_rects_ref << DrawnRect{x, y, width, height}
		}
	}

	mut mock_modal := FilePickerModal.new('**tfm**', [
		'./src/project/main.v',
		'./src/project/lib/some_utilities.v',
		'./src/project/lib/meta.v',
		'./src/project/lib/database/connection.v',
	], false)

	mock_modal.draw(mut mock_drawer)

	assert drawn_text.len > 0
	mut cleaned_list := drawn_text[1..drawn_text.len - 2].clone()
	assert cleaned_list == [
		'./src/project/main.v',
		'./src/project/lib/some_utilities.v',
		'./src/project/lib/meta.v',
		'./src/project/lib/database/connection.v',
	]
	assert drawn_rects == [
		DrawnRect{
			x:      0
			y:      1
			width:  500
			height: 20
		}, // this is the full background rect for the list
		DrawnRect{
			x:      0
			y:      1
			width:  500
			height: 1
		}, // this is the currently selected/heightlight line rect
		DrawnRect{
			x:      0
			y:      20
			width:  500
			height: 1
		}, // this is the rect/background line for the search bar
	]

	mock_modal.on_key_down(draw.Event{ ascii: u8('c'[0]) })
	mock_modal.on_key_down(draw.Event{ ascii: u8('o'[0]) })
	mock_modal.on_key_down(draw.Event{ ascii: u8('n'[0]) })

	drawn_text.clear()
	drawn_rects.clear()
	mock_modal.draw(mut mock_drawer)
	assert drawn_text.len > 0
	cleaned_list = drawn_text[1..drawn_text.len - 2].clone()
	assert cleaned_list == [
		'./src/project/lib/database/connection.v',
		'./src/project/main.v',
		'./src/project/lib/some_utilities.v',
		'./src/project/lib/meta.v',
	]
	assert drawn_rects == [
		DrawnRect{
			x:      0
			y:      1
			width:  500
			height: 20
		}, // this is the full background rect for the list
		DrawnRect{
			x:      0
			y:      1
			width:  500
			height: 1
		}, // this is the currently selected/heightlight line rect
		DrawnRect{
			x:      0
			y:      20
			width:  500
			height: 1
		}, // this is the rect/background line for the search bar
	]
}

fn test_current_selection_gets_zeros_on_search_term_amend() {
	mut mock_modal := FilePickerModal.new('**tfm**', [
		'./src/project/main.v',
		'./src/project/lib/some_utilities.v',
	], false)

	assert mock_modal.current_sel_id == 0
	mock_modal.on_key_down(draw.Event{ utf8: 'd' })
	assert mock_modal.current_sel_id == 0

	mock_modal.on_key_down(draw.Event{ code: .down })
	assert mock_modal.current_sel_id == 1

	mock_modal.on_key_down(draw.Event{ utf8: 'r' })
	assert mock_modal.current_sel_id == 0
}

fn test_reorder_file_paths_provides_realistic_results() {
	mut mock_modal := FilePickerModal.new('**tfm**', [
		'./src/project/main.v',
		'./src/project/lib/some_utilities.v',
	], false)

	mock_modal.search.query = 'some'
	mock_modal.reorder_file_paths()
	assert mock_modal.file_paths == [
		'./src/project/lib/some_utilities.v',
		'./src/project/main.v',
	]

	mock_modal.search.query = 'mai'
	mock_modal.reorder_file_paths()
	assert mock_modal.file_paths == [
		'./src/project/main.v',
		'./src/project/lib/some_utilities.v',
	]

	mock_modal.search.query = 'proj'
	mock_modal.reorder_file_paths()
	assert mock_modal.file_paths == [
		'./src/project/main.v',
		'./src/project/lib/some_utilities.v',
	]

	mock_modal.search.query = ''
	mock_modal.reorder_file_paths()
	assert mock_modal.file_paths == [
		'./src/project/main.v',
		'./src/project/lib/some_utilities.v',
	]

	mock_modal.search.query = 'zkf'
	mock_modal.reorder_file_paths()
	assert mock_modal.file_paths == [
		'./src/project/main.v',
		'./src/project/lib/some_utilities.v',
	]
}

fn test_score_values_by_query_success() {
	mut paths := [
		'./src/project/main.v',
		'./src/project/lib/some_utilities.v',
		'./src/project/lib/meta.v',
		'./src/project/lib/database/connection.v',
	]

	mut scores := []f32{len: paths.len}
	paths.sort_with_compare(fn (a &string, b &string) int {
		a_score := score_value_by_query('conn', a)
		b_score := score_value_by_query('conn', b)
		if a_score < b_score {
			return 1
		}
		if b_score > a_score {
			return -1
		}
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
