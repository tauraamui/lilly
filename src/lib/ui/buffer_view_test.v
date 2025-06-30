// Copyright 2025 The Lilly Editor contributors
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

// TODO(tauraamui) [16/06/2025]: about half of the tests in this file have been migrated to use the
//                               new mockcolorcontext ctx impl instead of the old mockcontext ctx impl.
//                               the rest need to be migrated over to this too, but for now we're not doing
//                               it because the focus needs to move back to using the new tests to assist
//                               working on visual + visual line mode selection highlighting functionality

module ui

import lib.buffer
import lib.draw
import lib.utf8
import lib.syntax
import lib.theme as themelib
import term.ui as tui

struct ColoredDrawnText {
	x        int
	y        int
	data     string
	fg_color tui.Color
	bg_color ?tui.Color
}

struct DrawnText {
	x int
	y int
	data string
}

struct DrawnRect {
	x      int
	y      int
	width  int
	height int
}

fn test_buffer_view_draws_lines_in_normal_mode_so_one_line_has_bg_the_rest_do_not() {
	mut drawn_text := []ColoredDrawnText{}
	mut drawn_text_ref := &drawn_text

	mut drawn_rect := []DrawnRect{}
	mut drawn_rect_ref := &drawn_rect

	mut mock_ctx := MockColorContextable{
		on_draw_cb: fn [
			mut drawn_text_ref
		] (x int, y int, text string, active_fg_color tui.Color, active_bg_color ?tui.Color) {
			drawn_text_ref << ColoredDrawnText{
				x, y, text, active_fg_color, active_bg_color
			}
		}
		on_draw_rect_cb: fn [mut drawn_rect_ref] (x int, y int, width int, height int) {
			drawn_rect_ref << DrawnRect{ x: x, y: y, width: width, height: height }
		}
	}

	mut buf := buffer.Buffer.new("", .legacy)
	for i in 0..5 { buf.lines << "This is line ${i} in the document" }
	mut buf_view := BufferView.new([], 0)

	x := 0
	y := 0
	width := 100
	height := 3
	min_x := 0
	from_line_num := 0

	buf_view.draw(
		mut mock_ctx, buf, x, y,
		width, height, from_line_num,
		min_x, false, .normal, BufferCursor{ pos: CursorPos{ x: 0, y: 1 } }
	)

	assert drawn_rect == [
		DrawnRect{ x: 2, y: 1, width: 99, height: 1 }
	]

	assert drawn_text.len == 56

	test_theme          := mock_ctx.theme()
	test_theme_pallete  := test_theme.pallete
	identifier_fg_color := test_theme_pallete[.identifier]
	whitespace_fg_color := test_theme_pallete[.whitespace]
	number_fg_color     := test_theme_pallete[.number]
	cursor_line_color   := test_theme.cursor_line_color
	line_num_fg_color :=   test_theme.line_number_color

	line_one_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 0, data: "1", fg_color: line_num_fg_color }, ColoredDrawnText{ x: 2, y: 0, data: "This", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 6, y: 0, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 7, y: 0, data: "is", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 9, y: 0, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 10, y: 0, data: "line", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 14, y: 0, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 15, y: 0, data: "0" fg_color: number_fg_color },
		ColoredDrawnText{ x: 16, y: 0, data: " " fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 17, y: 0, data: "in" fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 19, y: 0, data: " " fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 20, y: 0, data: "the" fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 23, y: 0, data: " " fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 24, y: 0, data: "document" fg_color: identifier_fg_color },
	]
	assert drawn_text[..14] == line_one_expected_drawn_data

	line_two_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 1, data: "2", fg_color: line_num_fg_color },
		ColoredDrawnText{ x: 2, y: 1, data: "This", fg_color: identifier_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 6, y: 1, data: " ", fg_color: whitespace_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 7, y: 1, data: "is", fg_color: identifier_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 9, y: 1, data: " ", fg_color: whitespace_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 10, y: 1, data: "line", fg_color: identifier_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 14, y: 1, data: " ", fg_color: whitespace_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 15, y: 1, data: "1", fg_color: number_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 16, y: 1, data: " ", fg_color: whitespace_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 17, y: 1, data: "in", fg_color: identifier_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 19, y: 1, data: " ", fg_color: whitespace_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 20, y: 1, data: "the", fg_color: identifier_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 23, y: 1, data: " ", fg_color: whitespace_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 24, y: 1, data: "document", fg_color: identifier_fg_color, bg_color: cursor_line_color },
	]
	assert drawn_text[14..28] == line_two_expected_drawn_data


	line_three_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 2, data: "3", fg_color: line_num_fg_color }, ColoredDrawnText{ x: 2, y: 2, data: "This", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 6, y: 2, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 7, y: 2, data: "is", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 9, y: 2, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 10, y: 2, data: "line", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 14, y: 2, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 15, y: 2, data: "2", fg_color: number_fg_color },
		ColoredDrawnText{ x: 16, y: 2, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 17, y: 2, data: "in", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 19, y: 2, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 20, y: 2, data: "the", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 23, y: 2, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 24, y: 2, data: "document", fg_color: identifier_fg_color },
	]
	assert drawn_text[28..42] == line_three_expected_drawn_data
}

fn test_buffer_view_draws_lines_in_visual_line_mode_just_top_line_selected() {
	mut drawn_text := []ColoredDrawnText{}
	mut drawn_text_ref := &drawn_text

	mut drawn_rect := []DrawnRect{}
	mut drawn_rect_ref := &drawn_rect

	mut mock_ctx := MockColorContextable{
		on_draw_cb: fn [
			mut drawn_text_ref
		] (x int, y int, text string, active_fg_color tui.Color, active_bg_color ?tui.Color) {
			drawn_text_ref << ColoredDrawnText{
				x, y, text, active_fg_color, active_bg_color
			}
		}
		on_draw_rect_cb: fn [mut drawn_rect_ref] (x int, y int, width int, height int) {
			drawn_rect_ref << DrawnRect{ x: x, y: y, width: width, height: height }
		}
	}

	mut buf := buffer.Buffer.new("", .legacy)
	for i in 0..5 { buf.lines << "This is line ${i} in the document" }
	mut buf_view := BufferView.new([], 0)

	x := 0
	y := 0
	width := 100
	height := 3
	min_x := 0
	from_line_num := 0

	buf_view.draw(
		mut mock_ctx, buf, x, y,
		width, height, from_line_num,
		min_x, false, .visual_line,
		BufferCursor{ pos: CursorPos{ x: 0, y: 1 }, sel_start_pos: CursorPos{ x:0, y: 1 } }
	)

	assert drawn_text.len == 56

	test_theme          := mock_ctx.theme()
	test_theme_pallete  := test_theme.pallete
	identifier_fg_color := test_theme_pallete[.identifier]
	whitespace_fg_color := test_theme_pallete[.whitespace]
	number_fg_color     := test_theme_pallete[.number]
	cursor_line_color   := test_theme.cursor_line_color
	selected_line_color := test_theme.selection_highlight_color
	line_num_fg_color :=   test_theme.line_number_color

	line_one_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 0, data: "1", fg_color: line_num_fg_color }, ColoredDrawnText{ x: 2, y: 0, data: "This", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 6, y: 0, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 7, y: 0, data: "is", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 9, y: 0, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 10, y: 0, data: "line", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 14, y: 0, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 15, y: 0, data: "0" fg_color: number_fg_color },
		ColoredDrawnText{ x: 16, y: 0, data: " " fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 17, y: 0, data: "in" fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 19, y: 0, data: " " fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 20, y: 0, data: "the" fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 23, y: 0, data: " " fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 24, y: 0, data: "document" fg_color: identifier_fg_color },
	]
	assert drawn_text[..14] == line_one_expected_drawn_data

	line_two_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 1, data: "2", fg_color: line_num_fg_color },
		ColoredDrawnText{ x: 2, y: 1, data: "This", fg_color: identifier_fg_color, bg_color: selected_line_color },
		ColoredDrawnText{ x: 6, y: 1, data: " ", fg_color: whitespace_fg_color, bg_color: selected_line_color },
		ColoredDrawnText{ x: 7, y: 1, data: "is", fg_color: identifier_fg_color, bg_color: selected_line_color },
		ColoredDrawnText{ x: 9, y: 1, data: " ", fg_color: whitespace_fg_color, bg_color: selected_line_color },
		ColoredDrawnText{ x: 10, y: 1, data: "line", fg_color: identifier_fg_color, bg_color: selected_line_color },
		ColoredDrawnText{ x: 14, y: 1, data: " ", fg_color: whitespace_fg_color, bg_color: selected_line_color },
		ColoredDrawnText{ x: 15, y: 1, data: "1", fg_color: number_fg_color, bg_color: selected_line_color },
		ColoredDrawnText{ x: 16, y: 1, data: " ", fg_color: whitespace_fg_color, bg_color: selected_line_color },
		ColoredDrawnText{ x: 17, y: 1, data: "in", fg_color: identifier_fg_color, bg_color: selected_line_color },
		ColoredDrawnText{ x: 19, y: 1, data: " ", fg_color: whitespace_fg_color, bg_color: selected_line_color },
		ColoredDrawnText{ x: 20, y: 1, data: "the", fg_color: identifier_fg_color, bg_color: selected_line_color },
		ColoredDrawnText{ x: 23, y: 1, data: " ", fg_color: whitespace_fg_color, bg_color: selected_line_color },
		ColoredDrawnText{ x: 24, y: 1, data: "document", fg_color: identifier_fg_color, bg_color: selected_line_color },
	]
	assert drawn_text[14..28] == line_two_expected_drawn_data


	line_three_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 2, data: "3", fg_color: line_num_fg_color }, ColoredDrawnText{ x: 2, y: 2, data: "This", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 6, y: 2, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 7, y: 2, data: "is", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 9, y: 2, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 10, y: 2, data: "line", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 14, y: 2, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 15, y: 2, data: "2", fg_color: number_fg_color },
		ColoredDrawnText{ x: 16, y: 2, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 17, y: 2, data: "in", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 19, y: 2, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 20, y: 2, data: "the", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 23, y: 2, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 24, y: 2, data: "document", fg_color: identifier_fg_color },
	]
	assert drawn_text[28..42] == line_three_expected_drawn_data
}

fn test_buffer_view_draws_lines_0_to_max_height() {
	mut drawn_text := []ColoredDrawnText{}
	mut drawn_text_ref := &drawn_text

	mut drawn_rect := []DrawnRect{}
	mut drawn_rect_ref := &drawn_rect

	mut mock_ctx := MockColorContextable{
		on_draw_cb: fn [mut drawn_text_ref] (x int, y int, text string, active_fg_color tui.Color, active_bg_color ?tui.Color) {
			drawn_text_ref << ColoredDrawnText{ x: x, y: y, data: text, fg_color: active_fg_color, bg_color: active_bg_color }
		}
		on_draw_rect_cb: fn [mut drawn_rect_ref] (x int, y int, width int, height int) {
			drawn_rect_ref << DrawnRect{ x: x, y: y, width: width, height: height }
		}
	}

	mut buf := buffer.Buffer.new("", .legacy)
	for i in 0..5 { buf.lines << "This is line ${i} in the document" }
	mut buf_view := BufferView.new([], 0)

	x := 0
	y := 0
	width := 100
	height := 3
	min_x := 0
	from_line_num := 0

	buf_view.draw(
		mut mock_ctx, buf, x, y,
		width, height, from_line_num,
		min_x, false, .normal, BufferCursor{}
	)

	assert drawn_rect == [
		DrawnRect{ x: 2, y: 0, width: 99, height: 1 }
	]

	assert drawn_text.len == 56

	test_theme          := mock_ctx.theme()
	test_theme_pallete  := test_theme.pallete
	identifier_fg_color := test_theme_pallete[.identifier]
	whitespace_fg_color := test_theme_pallete[.whitespace]
	number_fg_color     := test_theme_pallete[.number]
	cursor_line_color   := test_theme.cursor_line_color
	line_num_fg_color :=   test_theme.line_number_color

	line_one_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 0, data: "1", fg_color: line_num_fg_color },
		ColoredDrawnText{ x: 2, y: 0, data: "This", fg_color: identifier_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 6, y: 0, data: " ", fg_color: whitespace_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 7, y: 0, data: "is", fg_color: identifier_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 9, y: 0, data: " ", fg_color: whitespace_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 10, y: 0, data: "line", fg_color: identifier_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 14, y: 0, data: " ", fg_color: whitespace_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 15, y: 0, data: "0", fg_color: number_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 16, y: 0, data: " ", fg_color: whitespace_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 17, y: 0, data: "in", fg_color: identifier_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 19, y: 0, data: " ", fg_color: whitespace_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 20, y: 0, data: "the", fg_color: identifier_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 23, y: 0, data: " ", fg_color: whitespace_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 24, y: 0, data: "document", fg_color: identifier_fg_color, bg_color: cursor_line_color },
	]
	assert drawn_text[..14] == line_one_expected_drawn_data

	line_two_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 1, data: "2", fg_color: line_num_fg_color }, ColoredDrawnText{ x: 2, y: 1, data: "This", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 6, y: 1, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 7, y: 1, data: "is", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 9, y: 1, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 10, y: 1, data: "line", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 14, y: 1, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 15, y: 1, data: "1", fg_color: number_fg_color },
		ColoredDrawnText{ x: 16, y: 1, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 17, y: 1, data: "in", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 19, y: 1, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 20, y: 1, data: "the", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 23, y: 1, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 24, y: 1, data: "document", fg_color: identifier_fg_color },
	]
	assert drawn_text[14..28] == line_two_expected_drawn_data

	line_three_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 2, data: "3", fg_color: line_num_fg_color }, ColoredDrawnText{ x: 2, y: 2, data: "This", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 6, y: 2, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 7, y: 2, data: "is", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 9, y: 2, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 10, y: 2, data: "line", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 14, y: 2, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 15, y: 2, data: "2", fg_color: number_fg_color },
		ColoredDrawnText{ x: 16, y: 2, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 17, y: 2, data: "in", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 19, y: 2, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 20, y: 2, data: "the", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 23, y: 2, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 24, y: 2, data: "document", fg_color: identifier_fg_color },
	]
	assert drawn_text[28..42] == line_three_expected_drawn_data
}

fn test_buffer_view_draws_1_line_as_single_segment_that_that_elapses_max_width() {
	mut drawn_text := []ColoredDrawnText{}
	mut drawn_text_ref := &drawn_text

	mut drawn_rect := []DrawnRect{}
	mut drawn_rect_ref := &drawn_rect

	mut mock_ctx := MockColorContextable{
		on_draw_cb: fn [mut drawn_text_ref] (x int, y int, text string, active_fg_color tui.Color, active_bg_color ?tui.Color) {
			drawn_text_ref << ColoredDrawnText{ x: x, y: y, data: text, fg_color: active_fg_color, bg_color: active_bg_color }
		}
		on_draw_rect_cb: fn [mut drawn_rect_ref] (x int, y int, width int, height int) {
			drawn_rect_ref << DrawnRect{ x: x, y: y, width: width, height: height }
		}
	}

	mut buf := buffer.Buffer.new("", .legacy)
	buf.lines << "Thisisthelineinthedocument"
	mut buf_view := BufferView.new([], 0)

	x := 0
	y := 0
	width := 20
	height := 10
	min_x := 0
	from_line_num := 0

	buf_view.draw(
		mut mock_ctx, buf, x, y,
		width, height, from_line_num,
		min_x, false, .normal, BufferCursor{}
	)

	assert drawn_rect == [
		DrawnRect{ x: 2, y: 0, width: 19, height: 1 }
	]

	test_theme          := mock_ctx.theme()
	test_theme_pallete  := test_theme.pallete
	identifier_fg_color := test_theme_pallete[.identifier]
	cursor_line_color   := test_theme.cursor_line_color
	line_num_fg_color :=   test_theme.line_number_color

	line_one_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 0, data: "1", fg_color: line_num_fg_color },
		ColoredDrawnText{ x: 2, y: 0, data: "Thisisthelineinthe", fg_color: identifier_fg_color, bg_color: cursor_line_color },
	]
	assert drawn_text[..2] == line_one_expected_drawn_data
}

fn test_buffer_view_draws_1_line_as_multiple_segments_colored_as_expected() {
	mut drawn_text := []ColoredDrawnText{}
	mut drawn_text_ref := &drawn_text

	mut drawn_rect := []DrawnRect{}
	mut drawn_rect_ref := &drawn_rect

	mut mock_ctx := MockColorContextable{
		on_draw_cb: fn [mut drawn_text_ref] (x int, y int, text string, active_fg_color tui.Color, active_bg_color ?tui.Color) {
			drawn_text_ref << ColoredDrawnText{ x: x, y: y, data: text, fg_color: active_fg_color, bg_color: active_bg_color }
		}
		on_draw_rect_cb: fn [mut drawn_rect_ref] (x int, y int, width int, height int) {
			drawn_rect_ref << DrawnRect{ x: x, y: y, width: width, height: height }
		}
	}

	mut buf := buffer.Buffer.new("", .legacy)
	buf.lines << "fn name_of_function()"
	mut buf_view := BufferView.new([], 0)

	x := 0
	y := 0
	width := 40
	height := 10
	min_x := 0
	from_line_num := 0

	buf_view.draw(
		mut mock_ctx, buf, x, y,
		width, height, from_line_num,
		min_x, false, .normal, BufferCursor{}
	)

	assert drawn_rect == [
		DrawnRect{ x: 2, y: 0, width: 39, height: 1 }
	]

	test_theme          := mock_ctx.theme()
	test_theme_pallete  := test_theme.pallete
	identifier_fg_color := test_theme_pallete[.identifier]
	other_fg_color      := test_theme_pallete[.other]
	whitespace_fg_color := test_theme_pallete[.whitespace]
	cursor_line_color   := test_theme.cursor_line_color
	line_num_fg_color :=   test_theme.line_number_color

	assert drawn_text.len == 9

	line_one_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 0, data: "1", fg_color: line_num_fg_color },
		ColoredDrawnText{ x: 2, y: 0, data: "fn", fg_color: identifier_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 4, y: 0, data: " ", fg_color: whitespace_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 5, y: 0, data: "name", fg_color: identifier_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 9, y: 0, data: "_", fg_color: other_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 10, y: 0, data: "of", fg_color: identifier_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 12, y: 0, data: "_", fg_color: other_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 13, y: 0, data: "function", fg_color: identifier_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 21, y: 0, data: "()", fg_color: other_fg_color, bg_color: cursor_line_color },
	]
	assert drawn_text == line_one_expected_drawn_data
}

fn test_buffer_view_draws_1_line_as_single_segment_single_emoji() {
	mut drawn_text := []ColoredDrawnText{}
	mut drawn_text_ref := &drawn_text

	mut drawn_rect := []DrawnRect{}
	mut drawn_rect_ref := &drawn_rect

	mut mock_ctx := MockColorContextable{
		on_draw_cb: fn [mut drawn_text_ref] (x int, y int, text string, active_fg_color tui.Color, active_bg_color ?tui.Color) {
			drawn_text_ref << ColoredDrawnText{ x: x, y: y, data: text, fg_color: active_fg_color, bg_color: active_bg_color }
		}
		on_draw_rect_cb: fn [mut drawn_rect_ref] (x int, y int, width int, height int) {
			drawn_rect_ref << DrawnRect{ x: x, y: y, width: width, height: height }
		}
	}

	mut buf := buffer.Buffer.new("", .legacy)
	buf.lines << utf8.emoji_shark_char
	mut buf_view := BufferView.new([], 0)

	x := 0
	y := 0
	width := 20
	height := 10
	min_x := 0
	from_line_num := 0

	buf_view.draw(
		mut mock_ctx, buf, x, y,
		width, height, from_line_num,
		min_x, false, .normal, BufferCursor{}
	)

	assert drawn_rect == [
		DrawnRect{ x: 2, y: 0, width: 19, height: 1 }
	]

	test_theme          := mock_ctx.theme()
	test_theme_pallete  := test_theme.pallete
	other_fg_color := test_theme_pallete[.other]
	cursor_line_color   := test_theme.cursor_line_color
	line_num_fg_color :=   test_theme.line_number_color

	assert drawn_text.len == 2

	line_one_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 0, data: "1", fg_color: line_num_fg_color },
		ColoredDrawnText{ x: 2, y: 0, data: "${utf8.emoji_shark_char}", fg_color: other_fg_color, bg_color: cursor_line_color },
	]
	assert drawn_text[..2] == line_one_expected_drawn_data
}


fn test_buffer_view_draws_lines_10_to_max_height() {
	mut drawn_text := []ColoredDrawnText{}
	mut drawn_text_ref := &drawn_text

	mut drawn_rect := []DrawnRect{}
	mut drawn_rect_ref := &drawn_rect

	mut mock_ctx := MockColorContextable{
		on_draw_cb: fn [mut drawn_text_ref] (x int, y int, text string, active_fg_color tui.Color, active_bg_color ?tui.Color) {
			drawn_text_ref << ColoredDrawnText{ x: x, y: y, data: text, fg_color: active_fg_color, bg_color: active_bg_color }
		}
		on_draw_rect_cb: fn [mut drawn_rect_ref] (x int, y int, width int, height int) {
			drawn_rect_ref << DrawnRect{ x: x, y: y, width: width, height: height }
		}
	}

	mut buf := buffer.Buffer.new("", .legacy)
	for i in 0..20 { buf.lines << "This is line ${i} in the document" }
	mut buf_view := BufferView.new([], 0)

	x := 0
	y := 0
	width := 100
	height := 10
	min_x := 0
	from_line_num := 10

	buf_view.draw(
		mut mock_ctx, buf, x, y,
		width, height, from_line_num,
		min_x, false, .normal, BufferCursor{ pos: CursorPos{ y: 12 } }
	)

	assert drawn_rect == [
		DrawnRect{ x: 3, y: 2, width: 98, height: 1 }
	]

	test_theme          := mock_ctx.theme()
	test_theme_pallete  := test_theme.pallete
	identifier_fg_color := test_theme_pallete[.identifier]
	whitespace_fg_color := test_theme_pallete[.whitespace]
	number_fg_color     := test_theme_pallete[.number]
	cursor_line_color   := test_theme.cursor_line_color
	line_num_fg_color :=   test_theme.line_number_color

	assert drawn_text.len == 140

	line_one_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 0, data: "11", fg_color: line_num_fg_color }, ColoredDrawnText{ x: 3, y: 0, data: "This", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 7, y: 0, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 8, y: 0, data: "is", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 10, y: 0, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 11, y: 0, data: "line", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 15, y: 0, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 16, y: 0, data: "10", fg_color: number_fg_color },
		ColoredDrawnText{ x: 18, y: 0, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 19, y: 0, data: "in", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 21, y: 0, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 22, y: 0, data: "the", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 25, y: 0, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 26, y: 0, data: "document", fg_color: identifier_fg_color },
	]
	assert drawn_text[..14] == line_one_expected_drawn_data

	line_two_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 1, data: "12", fg_color: line_num_fg_color }, ColoredDrawnText{ x: 3, y: 1, data: "This", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 7, y: 1, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 8, y: 1, data: "is", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 10, y: 1, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 11, y: 1, data: "line", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 15, y: 1, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 16, y: 1, data: "11", fg_color: number_fg_color },
		ColoredDrawnText{ x: 18, y: 1, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 19, y: 1, data: "in", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 21, y: 1, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 22, y: 1, data: "the", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 25, y: 1, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 26, y: 1, data: "document", fg_color: identifier_fg_color },
	]
	assert drawn_text[14..28] == line_two_expected_drawn_data

	line_three_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 2, data: "13", fg_color: line_num_fg_color },
		ColoredDrawnText{ x: 3, y: 2, data: "This", fg_color: identifier_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 7, y: 2, data: " ", fg_color: whitespace_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 8, y: 2, data: "is", fg_color: identifier_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 10, y: 2, data: " ", fg_color: whitespace_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 11, y: 2, data: "line", fg_color: identifier_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 15, y: 2, data: " ", fg_color: whitespace_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 16, y: 2, data: "12", fg_color: number_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 18, y: 2, data: " ", fg_color: whitespace_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 19, y: 2, data: "in", fg_color: identifier_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 21, y: 2, data: " ", fg_color: whitespace_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 22, y: 2, data: "the", fg_color: identifier_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 25, y: 2, data: " ", fg_color: whitespace_fg_color, bg_color: cursor_line_color },
		ColoredDrawnText{ x: 26, y: 2, data: "document", fg_color: identifier_fg_color, bg_color: cursor_line_color },
	]
	assert drawn_text[28..42] == line_three_expected_drawn_data

	line_four_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 3, data: "14", fg_color: line_num_fg_color }, ColoredDrawnText{ x: 3, y: 3, data: "This", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 7, y: 3, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 8, y: 3, data: "is", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 10, y: 3, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 11, y: 3, data: "line", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 15, y: 3, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 16, y: 3, data: "13", fg_color: number_fg_color },
		ColoredDrawnText{ x: 18, y: 3, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 19, y: 3, data: "in", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 21, y: 3, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 22, y: 3, data: "the", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 25, y: 3, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 26, y: 3, data: "document", fg_color: identifier_fg_color },
	]
	assert drawn_text[42..56] == line_four_expected_drawn_data

	line_five_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 4, data: "15", fg_color: line_num_fg_color }, ColoredDrawnText{ x: 3, y: 4, data: "This", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 7, y: 4, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 8, y: 4, data: "is", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 10, y: 4, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 11, y: 4, data: "line", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 15, y: 4, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 16, y: 4, data: "14", fg_color: number_fg_color },
		ColoredDrawnText{ x: 18, y: 4, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 19, y: 4, data: "in", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 21, y: 4, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 22, y: 4, data: "the", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 25, y: 4, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 26, y: 4, data: "document", fg_color: identifier_fg_color },
	]
	assert drawn_text[56..70] == line_five_expected_drawn_data

	line_six_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 5, data: "16", fg_color: line_num_fg_color }, ColoredDrawnText{ x: 3, y: 5, data: "This", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 7, y: 5, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 8, y: 5, data: "is", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 10, y: 5, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 11, y: 5, data: "line", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 15, y: 5, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 16, y: 5, data: "15", fg_color: number_fg_color },
		ColoredDrawnText{ x: 18, y: 5, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 19, y: 5, data: "in", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 21, y: 5, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 22, y: 5, data: "the", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 25, y: 5, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 26, y: 5, data: "document", fg_color: identifier_fg_color },
	]
	assert drawn_text[70..84] == line_six_expected_drawn_data

	line_seven_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 6, data: "17", fg_color: line_num_fg_color }, ColoredDrawnText{ x: 3, y: 6, data: "This", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 7, y: 6, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 8, y: 6, data: "is", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 10, y: 6, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 11, y: 6, data: "line", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 15, y: 6, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 16, y: 6, data: "16", fg_color: number_fg_color },
		ColoredDrawnText{ x: 18, y: 6, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 19, y: 6, data: "in", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 21, y: 6, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 22, y: 6, data: "the", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 25, y: 6, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 26, y: 6, data: "document", fg_color: identifier_fg_color },
	]
	assert drawn_text[84..98] == line_seven_expected_drawn_data

	line_eight_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 7, data: "18", fg_color: line_num_fg_color }, ColoredDrawnText{ x: 3, y: 7, data: "This", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 7, y: 7, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 8, y: 7, data: "is", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 10, y: 7, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 11, y: 7, data: "line", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 15, y: 7, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 16, y: 7, data: "17", fg_color: number_fg_color },
		ColoredDrawnText{ x: 18, y: 7, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 19, y: 7, data: "in", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 21, y: 7, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 22, y: 7, data: "the", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 25, y: 7, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 26, y: 7, data: "document", fg_color: identifier_fg_color },
	]
	assert drawn_text[98..112] == line_eight_expected_drawn_data

	line_nine_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 8, data: "19", fg_color: line_num_fg_color }, ColoredDrawnText{ x: 3, y: 8, data: "This", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 7, y: 8, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 8, y: 8, data: "is", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 10, y: 8, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 11, y: 8, data: "line", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 15, y: 8, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 16, y: 8, data: "18", fg_color: number_fg_color },
		ColoredDrawnText{ x: 18, y: 8, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 19, y: 8, data: "in", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 21, y: 8, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 22, y: 8, data: "the", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 25, y: 8, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 26, y: 8, data: "document", fg_color: identifier_fg_color },
	]
	assert drawn_text[112..126] == line_nine_expected_drawn_data

	line_ten_expected_drawn_data := [
		ColoredDrawnText{ x: 0, y: 9, data: "20", fg_color: line_num_fg_color }, ColoredDrawnText{ x: 3, y: 9, data: "This", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 7, y: 9, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 8, y: 9, data: "is", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 10, y: 9, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 11, y: 9, data: "line", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 15, y: 9, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 16, y: 9, data: "19", fg_color: number_fg_color },
		ColoredDrawnText{ x: 18, y: 9, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 19, y: 9, data: "in", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 21, y: 9, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 22, y: 9, data: "the", fg_color: identifier_fg_color },
		ColoredDrawnText{ x: 25, y: 9, data: " ", fg_color: whitespace_fg_color }, ColoredDrawnText{ x: 26, y: 9, data: "document", fg_color: identifier_fg_color },
	]
	assert drawn_text[126..140] == line_ten_expected_drawn_data
}

fn test_buffer_view_draws_lines_10_to_max_height_relative_line_numbers_enabled() {
	mut drawn_text := []DrawnText{}
	mut drawn_text_ref := &drawn_text

	mut set_fg_color := []tui.Color{}
	mut set_fg_color_ref := &set_fg_color

	mut set_bg_color := []tui.Color{}
	mut set_bg_color_ref := &set_bg_color

	mut drawn_rect := []DrawnRect{}
	mut drawn_rect_ref := &drawn_rect

	mut mock_ctx := MockContextable{
		on_draw_cb: fn [mut drawn_text_ref] (x int, y int, text string) {
			drawn_text_ref << DrawnText{ x: x, y: y, data: text }
		}
		on_draw_rect_cb: fn [mut drawn_rect_ref] (x int, y int, width int, height int) {
			drawn_rect_ref << DrawnRect{ x: x, y: y, width: width, height: height }
		}
		on_set_fg_color_cb: fn [mut set_fg_color_ref] (c draw.Color) {
			set_fg_color_ref << tui.Color{ r: c.r, g: c.g, b: c.b }
		}
		on_set_bg_color_cb: fn [mut set_bg_color_ref] (c draw.Color) {
			set_bg_color_ref << tui.Color{ r: c.r, g: c.g, b: c.b }
		}
	}

	mut buf := buffer.Buffer.new("", .legacy)
	for i in 0..20 { buf.lines << "This is line ${i} in the document" }
	mut buf_view := BufferView.new([], 0)

	x := 0
	y := 0
	width := 100
	height := 10
	min_x := 0
	from_line_num := 10

	buf_view.draw(
		mut mock_ctx, buf, x, y,
		width, height, from_line_num,
		min_x, true, .normal, BufferCursor{ pos: CursorPos{ y: 15 } }
	) // toggle relative line numbers on

	assert set_bg_color == [tui.Color{ 53, 53, 53 }, tui.Color{ 53, 53, 53 }]
	assert drawn_rect == [
		DrawnRect{ x: 3, y: 5, width: 98, height: 1 }
	]

	assert drawn_text.len == 140
	assert set_fg_color.len == 140

	line_num_fg_color := mock_ctx.theme().line_number_color

	assert set_fg_color[0] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[1])? == .identifier
	assert themelib.color_to_type(set_fg_color[2])? == .whitespace
	assert themelib.color_to_type(set_fg_color[3])? == .identifier
	assert themelib.color_to_type(set_fg_color[4])? == .whitespace
	assert themelib.color_to_type(set_fg_color[5])? == .identifier
	assert themelib.color_to_type(set_fg_color[6])? == .whitespace
	assert themelib.color_to_type(set_fg_color[7])? == .number
	assert themelib.color_to_type(set_fg_color[8])? == .whitespace
	assert themelib.color_to_type(set_fg_color[9])? == .identifier
	assert themelib.color_to_type(set_fg_color[10])? == .whitespace
	assert themelib.color_to_type(set_fg_color[11])? == .identifier
	assert themelib.color_to_type(set_fg_color[12])? == .whitespace
	assert themelib.color_to_type(set_fg_color[13])? == .identifier

	assert set_fg_color[14] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[15])? == .identifier
	assert themelib.color_to_type(set_fg_color[16])? == .whitespace
	assert themelib.color_to_type(set_fg_color[17])? == .identifier
	assert themelib.color_to_type(set_fg_color[18])? == .whitespace
	assert themelib.color_to_type(set_fg_color[19])? == .identifier
	assert themelib.color_to_type(set_fg_color[20])? == .whitespace
	assert themelib.color_to_type(set_fg_color[21])? == .number
	assert themelib.color_to_type(set_fg_color[22])? == .whitespace
	assert themelib.color_to_type(set_fg_color[23])? == .identifier
	assert themelib.color_to_type(set_fg_color[24])? == .whitespace
	assert themelib.color_to_type(set_fg_color[25])? == .identifier
	assert themelib.color_to_type(set_fg_color[26])? == .whitespace
	assert themelib.color_to_type(set_fg_color[27])? == .identifier

	assert set_fg_color[28] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[29])? == .identifier
	assert themelib.color_to_type(set_fg_color[30])? == .whitespace
	assert themelib.color_to_type(set_fg_color[31])? == .identifier
	assert themelib.color_to_type(set_fg_color[33])? == .identifier
	assert themelib.color_to_type(set_fg_color[34])? == .whitespace
	assert themelib.color_to_type(set_fg_color[35])? == .number
	assert themelib.color_to_type(set_fg_color[36])? == .whitespace
	assert themelib.color_to_type(set_fg_color[37])? == .identifier
	assert themelib.color_to_type(set_fg_color[38])? == .whitespace
	assert themelib.color_to_type(set_fg_color[39])? == .identifier
	assert themelib.color_to_type(set_fg_color[40])? == .whitespace
	assert themelib.color_to_type(set_fg_color[41])? == .identifier

	assert set_fg_color[42] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[43])? == .identifier
	assert themelib.color_to_type(set_fg_color[44])? == .whitespace
	assert themelib.color_to_type(set_fg_color[45])? == .identifier
	assert themelib.color_to_type(set_fg_color[46])? == .whitespace
	assert themelib.color_to_type(set_fg_color[47])? == .identifier
	assert themelib.color_to_type(set_fg_color[48])? == .whitespace
	assert themelib.color_to_type(set_fg_color[49])? == .number
	assert themelib.color_to_type(set_fg_color[50])? == .whitespace
	assert themelib.color_to_type(set_fg_color[51])? == .identifier
	assert themelib.color_to_type(set_fg_color[52])? == .whitespace
	assert themelib.color_to_type(set_fg_color[53])? == .identifier
	assert themelib.color_to_type(set_fg_color[54])? == .whitespace
	assert themelib.color_to_type(set_fg_color[55])? == .identifier

	assert set_fg_color[56] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[57])? == .identifier
	assert themelib.color_to_type(set_fg_color[58])? == .whitespace
	assert themelib.color_to_type(set_fg_color[59])? == .identifier
	assert themelib.color_to_type(set_fg_color[60])? == .whitespace
	assert themelib.color_to_type(set_fg_color[61])? == .identifier
	assert themelib.color_to_type(set_fg_color[62])? == .whitespace
	assert themelib.color_to_type(set_fg_color[63])? == .number
	assert themelib.color_to_type(set_fg_color[64])? == .whitespace
	assert themelib.color_to_type(set_fg_color[65])? == .identifier
	assert themelib.color_to_type(set_fg_color[66])? == .whitespace
	assert themelib.color_to_type(set_fg_color[67])? == .identifier
	assert themelib.color_to_type(set_fg_color[68])? == .whitespace
	assert themelib.color_to_type(set_fg_color[69])? == .identifier

	assert set_fg_color[70] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[71])? == .identifier
	assert themelib.color_to_type(set_fg_color[72])? == .whitespace
	assert themelib.color_to_type(set_fg_color[73])? == .identifier
	assert themelib.color_to_type(set_fg_color[74])? == .whitespace
	assert themelib.color_to_type(set_fg_color[75])? == .identifier
	assert themelib.color_to_type(set_fg_color[76])? == .whitespace
	assert themelib.color_to_type(set_fg_color[77])? == .number
	assert themelib.color_to_type(set_fg_color[78])? == .whitespace
	assert themelib.color_to_type(set_fg_color[79])? == .identifier
	assert themelib.color_to_type(set_fg_color[80])? == .whitespace
	assert themelib.color_to_type(set_fg_color[81])? == .identifier
	assert themelib.color_to_type(set_fg_color[82])? == .whitespace
	assert themelib.color_to_type(set_fg_color[83])? == .identifier

	assert set_fg_color[84] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[85])? == .identifier
	assert themelib.color_to_type(set_fg_color[86])? == .whitespace
	assert themelib.color_to_type(set_fg_color[87])? == .identifier
	assert themelib.color_to_type(set_fg_color[88])? == .whitespace
	assert themelib.color_to_type(set_fg_color[89])? == .identifier
	assert themelib.color_to_type(set_fg_color[90])? == .whitespace
	assert themelib.color_to_type(set_fg_color[91])? == .number
	assert themelib.color_to_type(set_fg_color[92])? == .whitespace
	assert themelib.color_to_type(set_fg_color[93])? == .identifier
	assert themelib.color_to_type(set_fg_color[94])? == .whitespace
	assert themelib.color_to_type(set_fg_color[95])? == .identifier
	assert themelib.color_to_type(set_fg_color[96])? == .whitespace
	assert themelib.color_to_type(set_fg_color[97])? == .identifier

	assert set_fg_color[98] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[99])? == .identifier
	assert themelib.color_to_type(set_fg_color[100])? == .whitespace
	assert themelib.color_to_type(set_fg_color[101])? == .identifier
	assert themelib.color_to_type(set_fg_color[102])? == .whitespace
	assert themelib.color_to_type(set_fg_color[103])? == .identifier
	assert themelib.color_to_type(set_fg_color[104])? == .whitespace
	assert themelib.color_to_type(set_fg_color[105])? == .number
	assert themelib.color_to_type(set_fg_color[106])? == .whitespace
	assert themelib.color_to_type(set_fg_color[107])? == .identifier
	assert themelib.color_to_type(set_fg_color[108])? == .whitespace
	assert themelib.color_to_type(set_fg_color[109])? == .identifier
	assert themelib.color_to_type(set_fg_color[110])? == .whitespace
	assert themelib.color_to_type(set_fg_color[111])? == .identifier

	assert set_fg_color[112] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[113])? == .identifier
	assert themelib.color_to_type(set_fg_color[114])? == .whitespace
	assert themelib.color_to_type(set_fg_color[115])? == .identifier
	assert themelib.color_to_type(set_fg_color[116])? == .whitespace
	assert themelib.color_to_type(set_fg_color[117])? == .identifier
	assert themelib.color_to_type(set_fg_color[118])? == .whitespace
	assert themelib.color_to_type(set_fg_color[119])? == .number
	assert themelib.color_to_type(set_fg_color[120])? == .whitespace
	assert themelib.color_to_type(set_fg_color[121])? == .identifier
	assert themelib.color_to_type(set_fg_color[122])? == .whitespace
	assert themelib.color_to_type(set_fg_color[123])? == .identifier
	assert themelib.color_to_type(set_fg_color[124])? == .whitespace
	assert themelib.color_to_type(set_fg_color[125])? == .identifier

	assert set_fg_color[126] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[127])? == .identifier
	assert themelib.color_to_type(set_fg_color[127])? == .identifier
	assert themelib.color_to_type(set_fg_color[128])? == .whitespace
	assert themelib.color_to_type(set_fg_color[129])? == .identifier
	assert themelib.color_to_type(set_fg_color[130])? == .whitespace
	assert themelib.color_to_type(set_fg_color[131])? == .identifier
	assert themelib.color_to_type(set_fg_color[132])? == .whitespace
	assert themelib.color_to_type(set_fg_color[133])? == .number
	assert themelib.color_to_type(set_fg_color[134])? == .whitespace
	assert themelib.color_to_type(set_fg_color[135])? == .identifier
	assert themelib.color_to_type(set_fg_color[136])? == .whitespace
	assert themelib.color_to_type(set_fg_color[137])? == .identifier
	assert themelib.color_to_type(set_fg_color[138])? == .whitespace
	assert themelib.color_to_type(set_fg_color[139])? == .identifier

	line_one_expected_drawn_data := [
		DrawnText{ x: 1, y: 0, data: "5" }, DrawnText{ x: 3, y: 0, data: "This" },
		DrawnText{ x: 7, y: 0, data: " " }, DrawnText{ x: 8, y: 0, data: "is" },
		DrawnText{ x: 10, y: 0, data: " " }, DrawnText{ x: 11, y: 0, data: "line" },
		DrawnText{ x: 15, y: 0, data: " " }, DrawnText{ x: 16, y: 0, data: "10" },
		DrawnText{ x: 18, y: 0, data: " " }, DrawnText{ x: 19, y: 0, data: "in" },
		DrawnText{ x: 21, y: 0, data: " " }, DrawnText{ x: 22, y: 0, data: "the" },
		DrawnText{ x: 25, y: 0, data: " " }, DrawnText{ x: 26, y: 0, data: "document" },
	]
	assert drawn_text[..14] == line_one_expected_drawn_data

	line_two_expected_drawn_data := [
		DrawnText{ x: 1, y: 1, data: "4" }, DrawnText{ x: 3, y: 1, data: "This" },
		DrawnText{ x: 7, y: 1, data: " " }, DrawnText{ x: 8, y: 1, data: "is" },
		DrawnText{ x: 10, y: 1, data: " " }, DrawnText{ x: 11, y: 1, data: "line" },
		DrawnText{ x: 15, y: 1, data: " " }, DrawnText{ x: 16, y: 1, data: "11" },
		DrawnText{ x: 18, y: 1, data: " " }, DrawnText{ x: 19, y: 1, data: "in" },
		DrawnText{ x: 21, y: 1, data: " " }, DrawnText{ x: 22, y: 1, data: "the" },
		DrawnText{ x: 25, y: 1, data: " " }, DrawnText{ x: 26, y: 1, data: "document" },
	]
	assert drawn_text[14..28] == line_two_expected_drawn_data

	line_three_expected_drawn_data := [
		DrawnText{ x: 1, y: 2, data: "3" }, DrawnText{ x: 3, y: 2, data: "This" },
		DrawnText{ x: 7, y: 2, data: " " }, DrawnText{ x: 8, y: 2, data: "is" },
		DrawnText{ x: 10, y: 2, data: " " }, DrawnText{ x: 11, y: 2, data: "line" },
		DrawnText{ x: 15, y: 2, data: " " }, DrawnText{ x: 16, y: 2, data: "12" },
		DrawnText{ x: 18, y: 2, data: " " }, DrawnText{ x: 19, y: 2, data: "in" },
		DrawnText{ x: 21, y: 2, data: " " }, DrawnText{ x: 22, y: 2, data: "the" },
		DrawnText{ x: 25, y: 2, data: " " }, DrawnText{ x: 26, y: 2, data: "document" },
	]
	assert drawn_text[28..42] == line_three_expected_drawn_data

	line_four_expected_drawn_data := [
		DrawnText{ x: 1, y: 3, data: "2" }, DrawnText{ x: 3, y: 3, data: "This" },
		DrawnText{ x: 7, y: 3, data: " " }, DrawnText{ x: 8, y: 3, data: "is" },
		DrawnText{ x: 10, y: 3, data: " " }, DrawnText{ x: 11, y: 3, data: "line" },
		DrawnText{ x: 15, y: 3, data: " " }, DrawnText{ x: 16, y: 3, data: "13" },
		DrawnText{ x: 18, y: 3, data: " " }, DrawnText{ x: 19, y: 3, data: "in" },
		DrawnText{ x: 21, y: 3, data: " " }, DrawnText{ x: 22, y: 3, data: "the" },
		DrawnText{ x: 25, y: 3, data: " " }, DrawnText{ x: 26, y: 3, data: "document" },
	]
	assert drawn_text[42..56] == line_four_expected_drawn_data

	line_five_expected_drawn_data := [
		DrawnText{ x: 1, y: 4, data: "1" }, DrawnText{ x: 3, y: 4, data: "This" },
		DrawnText{ x: 7, y: 4, data: " " }, DrawnText{ x: 8, y: 4, data: "is" },
		DrawnText{ x: 10, y: 4, data: " " }, DrawnText{ x: 11, y: 4, data: "line" },
		DrawnText{ x: 15, y: 4, data: " " }, DrawnText{ x: 16, y: 4, data: "14" },
		DrawnText{ x: 18, y: 4, data: " " }, DrawnText{ x: 19, y: 4, data: "in" },
		DrawnText{ x: 21, y: 4, data: " " }, DrawnText{ x: 22, y: 4, data: "the" },
		DrawnText{ x: 25, y: 4, data: " " }, DrawnText{ x: 26, y: 4, data: "document" },
	]
	assert drawn_text[56..70] == line_five_expected_drawn_data

	line_six_expected_drawn_data := [
		DrawnText{ x: 0, y: 5, data: "16" }, DrawnText{ x: 3, y: 5, data: "This" },
		DrawnText{ x: 7, y: 5, data: " " }, DrawnText{ x: 8, y: 5, data: "is" },
		DrawnText{ x: 10, y: 5, data: " " }, DrawnText{ x: 11, y: 5, data: "line" },
		DrawnText{ x: 15, y: 5, data: " " }, DrawnText{ x: 16, y: 5, data: "15" },
		DrawnText{ x: 18, y: 5, data: " " }, DrawnText{ x: 19, y: 5, data: "in" },
		DrawnText{ x: 21, y: 5, data: " " }, DrawnText{ x: 22, y: 5, data: "the" },
		DrawnText{ x: 25, y: 5, data: " " }, DrawnText{ x: 26, y: 5, data: "document" },
	]
	assert drawn_text[70..84] == line_six_expected_drawn_data

	line_seven_expected_drawn_data := [
		DrawnText{ x: 1, y: 6, data: "1" }, DrawnText{ x: 3, y: 6, data: "This" },
		DrawnText{ x: 7, y: 6, data: " " }, DrawnText{ x: 8, y: 6, data: "is" },
		DrawnText{ x: 10, y: 6, data: " " }, DrawnText{ x: 11, y: 6, data: "line" },
		DrawnText{ x: 15, y: 6, data: " " }, DrawnText{ x: 16, y: 6, data: "16" },
		DrawnText{ x: 18, y: 6, data: " " }, DrawnText{ x: 19, y: 6, data: "in" },
		DrawnText{ x: 21, y: 6, data: " " }, DrawnText{ x: 22, y: 6, data: "the" },
		DrawnText{ x: 25, y: 6, data: " " }, DrawnText{ x: 26, y: 6, data: "document" },
	]
	assert drawn_text[84..98] == line_seven_expected_drawn_data

	line_eight_expected_drawn_data := [
		DrawnText{ x: 1, y: 7, data: "2" }, DrawnText{ x: 3, y: 7, data: "This" },
		DrawnText{ x: 7, y: 7, data: " " }, DrawnText{ x: 8, y: 7, data: "is" },
		DrawnText{ x: 10, y: 7, data: " " }, DrawnText{ x: 11, y: 7, data: "line" },
		DrawnText{ x: 15, y: 7, data: " " }, DrawnText{ x: 16, y: 7, data: "17" },
		DrawnText{ x: 18, y: 7, data: " " }, DrawnText{ x: 19, y: 7, data: "in" },
		DrawnText{ x: 21, y: 7, data: " " }, DrawnText{ x: 22, y: 7, data: "the" },
		DrawnText{ x: 25, y: 7, data: " " }, DrawnText{ x: 26, y: 7, data: "document" },
	]
	assert drawn_text[98..112] == line_eight_expected_drawn_data

	line_nine_expected_drawn_data := [
		DrawnText{ x: 1, y: 8, data: "3" }, DrawnText{ x: 3, y: 8, data: "This" },
		DrawnText{ x: 7, y: 8, data: " " }, DrawnText{ x: 8, y: 8, data: "is" },
		DrawnText{ x: 10, y: 8, data: " " }, DrawnText{ x: 11, y: 8, data: "line" },
		DrawnText{ x: 15, y: 8, data: " " }, DrawnText{ x: 16, y: 8, data: "18" },
		DrawnText{ x: 18, y: 8, data: " " }, DrawnText{ x: 19, y: 8, data: "in" },
		DrawnText{ x: 21, y: 8, data: " " }, DrawnText{ x: 22, y: 8, data: "the" },
		DrawnText{ x: 25, y: 8, data: " " }, DrawnText{ x: 26, y: 8, data: "document" },
	]
	assert drawn_text[112..126] == line_nine_expected_drawn_data

	line_ten_expected_drawn_data := [
		DrawnText{ x: 1, y: 9, data: "4" }, DrawnText{ x: 3, y: 9, data: "This" },
		DrawnText{ x: 7, y: 9, data: " " }, DrawnText{ x: 8, y: 9, data: "is" },
		DrawnText{ x: 10, y: 9, data: " " }, DrawnText{ x: 11, y: 9, data: "line" },
		DrawnText{ x: 15, y: 9, data: " " }, DrawnText{ x: 16, y: 9, data: "19" },
		DrawnText{ x: 18, y: 9, data: " " }, DrawnText{ x: 19, y: 9, data: "in" },
		DrawnText{ x: 21, y: 9, data: " " }, DrawnText{ x: 22, y: 9, data: "the" },
		DrawnText{ x: 25, y: 9, data: " " }, DrawnText{ x: 26, y: 9, data: "document" },
	]
	assert drawn_text[126..140] == line_ten_expected_drawn_data
}

fn test_buffer_view_draws_lines_10_to_max_height_relative_line_numbers_enabled_cursorline_movement_updates_relative_nums() {
	mut drawn_text := []DrawnText{}
	mut drawn_text_ref := &drawn_text

	mut set_fg_color := []tui.Color{}
	mut set_fg_color_ref := &set_fg_color

	mut set_bg_color := []tui.Color{}
	mut set_bg_color_ref := &set_bg_color

	mut drawn_rect := []DrawnRect{}
	mut drawn_rect_ref := &drawn_rect

	mut mock_ctx := MockContextable{
		on_draw_cb: fn [mut drawn_text_ref] (x int, y int, text string) {
			drawn_text_ref << DrawnText{ x: x, y: y, data: text }
		}
		on_draw_rect_cb: fn [mut drawn_rect_ref] (x int, y int, width int, height int) {
			drawn_rect_ref << DrawnRect{ x: x, y: y, width: width, height: height }
		}
		on_set_fg_color_cb: fn [mut set_fg_color_ref] (c draw.Color) {
			set_fg_color_ref << tui.Color{ r: c.r, g: c.g, b: c.b }
		}
		on_set_bg_color_cb: fn [mut set_bg_color_ref] (c draw.Color) {
			set_bg_color_ref << tui.Color{ r: c.r, g: c.g, b: c.b }
		}
	}

	mut buf := buffer.Buffer.new("", .legacy)
	for i in 0..20 { buf.lines << "This is line ${i} in the document" }
	mut buf_view := BufferView.new([], 0)

	x := 0
	y := 0
	width := 100
	height := 10
	min_x := 0
	from_line_num := 10

	buf_view.draw(
		mut mock_ctx, buf, x, y,
		width, height, from_line_num,
		min_x, true, .normal, BufferCursor{ pos: CursorPos{ y: 15 } }
	) // toggle relative line numbers on

	assert set_bg_color == [tui.Color{ 53, 53, 53 }, tui.Color{ 53, 53, 53 }]
	assert drawn_rect == [
		DrawnRect{ x: 3, y: 5, width: 98, height: 1 }
	]

	assert drawn_text.len == 140
	assert set_fg_color.len == 140

	line_num_fg_color := mock_ctx.theme().line_number_color

	assert set_fg_color[0] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[1])? == .identifier
	assert themelib.color_to_type(set_fg_color[2])? == .whitespace
	assert themelib.color_to_type(set_fg_color[3])? == .identifier
	assert themelib.color_to_type(set_fg_color[4])? == .whitespace
	assert themelib.color_to_type(set_fg_color[5])? == .identifier
	assert themelib.color_to_type(set_fg_color[6])? == .whitespace
	assert themelib.color_to_type(set_fg_color[7])? == .number
	assert themelib.color_to_type(set_fg_color[8])? == .whitespace
	assert themelib.color_to_type(set_fg_color[9])? == .identifier
	assert themelib.color_to_type(set_fg_color[10])? == .whitespace
	assert themelib.color_to_type(set_fg_color[11])? == .identifier
	assert themelib.color_to_type(set_fg_color[12])? == .whitespace
	assert themelib.color_to_type(set_fg_color[13])? == .identifier

	assert set_fg_color[14] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[15])? == .identifier
	assert themelib.color_to_type(set_fg_color[16])? == .whitespace
	assert themelib.color_to_type(set_fg_color[17])? == .identifier
	assert themelib.color_to_type(set_fg_color[18])? == .whitespace
	assert themelib.color_to_type(set_fg_color[19])? == .identifier
	assert themelib.color_to_type(set_fg_color[20])? == .whitespace
	assert themelib.color_to_type(set_fg_color[21])? == .number
	assert themelib.color_to_type(set_fg_color[22])? == .whitespace
	assert themelib.color_to_type(set_fg_color[23])? == .identifier
	assert themelib.color_to_type(set_fg_color[24])? == .whitespace
	assert themelib.color_to_type(set_fg_color[25])? == .identifier
	assert themelib.color_to_type(set_fg_color[26])? == .whitespace
	assert themelib.color_to_type(set_fg_color[27])? == .identifier

	assert set_fg_color[28] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[29])? == .identifier
	assert themelib.color_to_type(set_fg_color[30])? == .whitespace
	assert themelib.color_to_type(set_fg_color[31])? == .identifier
	assert themelib.color_to_type(set_fg_color[33])? == .identifier
	assert themelib.color_to_type(set_fg_color[34])? == .whitespace
	assert themelib.color_to_type(set_fg_color[35])? == .number
	assert themelib.color_to_type(set_fg_color[36])? == .whitespace
	assert themelib.color_to_type(set_fg_color[37])? == .identifier
	assert themelib.color_to_type(set_fg_color[38])? == .whitespace
	assert themelib.color_to_type(set_fg_color[39])? == .identifier
	assert themelib.color_to_type(set_fg_color[40])? == .whitespace
	assert themelib.color_to_type(set_fg_color[41])? == .identifier

	assert set_fg_color[42] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[43])? == .identifier
	assert themelib.color_to_type(set_fg_color[44])? == .whitespace
	assert themelib.color_to_type(set_fg_color[45])? == .identifier
	assert themelib.color_to_type(set_fg_color[46])? == .whitespace
	assert themelib.color_to_type(set_fg_color[47])? == .identifier
	assert themelib.color_to_type(set_fg_color[48])? == .whitespace
	assert themelib.color_to_type(set_fg_color[49])? == .number
	assert themelib.color_to_type(set_fg_color[50])? == .whitespace
	assert themelib.color_to_type(set_fg_color[51])? == .identifier
	assert themelib.color_to_type(set_fg_color[52])? == .whitespace
	assert themelib.color_to_type(set_fg_color[53])? == .identifier
	assert themelib.color_to_type(set_fg_color[54])? == .whitespace
	assert themelib.color_to_type(set_fg_color[55])? == .identifier

	assert set_fg_color[56] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[57])? == .identifier
	assert themelib.color_to_type(set_fg_color[58])? == .whitespace
	assert themelib.color_to_type(set_fg_color[59])? == .identifier
	assert themelib.color_to_type(set_fg_color[60])? == .whitespace
	assert themelib.color_to_type(set_fg_color[61])? == .identifier
	assert themelib.color_to_type(set_fg_color[62])? == .whitespace
	assert themelib.color_to_type(set_fg_color[63])? == .number
	assert themelib.color_to_type(set_fg_color[64])? == .whitespace
	assert themelib.color_to_type(set_fg_color[65])? == .identifier
	assert themelib.color_to_type(set_fg_color[66])? == .whitespace
	assert themelib.color_to_type(set_fg_color[67])? == .identifier
	assert themelib.color_to_type(set_fg_color[68])? == .whitespace
	assert themelib.color_to_type(set_fg_color[69])? == .identifier

	assert set_fg_color[70] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[71])? == .identifier
	assert themelib.color_to_type(set_fg_color[72])? == .whitespace
	assert themelib.color_to_type(set_fg_color[73])? == .identifier
	assert themelib.color_to_type(set_fg_color[74])? == .whitespace
	assert themelib.color_to_type(set_fg_color[75])? == .identifier
	assert themelib.color_to_type(set_fg_color[76])? == .whitespace
	assert themelib.color_to_type(set_fg_color[77])? == .number
	assert themelib.color_to_type(set_fg_color[78])? == .whitespace
	assert themelib.color_to_type(set_fg_color[79])? == .identifier
	assert themelib.color_to_type(set_fg_color[80])? == .whitespace
	assert themelib.color_to_type(set_fg_color[81])? == .identifier
	assert themelib.color_to_type(set_fg_color[82])? == .whitespace
	assert themelib.color_to_type(set_fg_color[83])? == .identifier

	assert set_fg_color[84] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[85])? == .identifier
	assert themelib.color_to_type(set_fg_color[86])? == .whitespace
	assert themelib.color_to_type(set_fg_color[87])? == .identifier
	assert themelib.color_to_type(set_fg_color[88])? == .whitespace
	assert themelib.color_to_type(set_fg_color[89])? == .identifier
	assert themelib.color_to_type(set_fg_color[90])? == .whitespace
	assert themelib.color_to_type(set_fg_color[91])? == .number
	assert themelib.color_to_type(set_fg_color[92])? == .whitespace
	assert themelib.color_to_type(set_fg_color[93])? == .identifier
	assert themelib.color_to_type(set_fg_color[94])? == .whitespace
	assert themelib.color_to_type(set_fg_color[95])? == .identifier
	assert themelib.color_to_type(set_fg_color[96])? == .whitespace
	assert themelib.color_to_type(set_fg_color[97])? == .identifier

	assert set_fg_color[98] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[99])? == .identifier
	assert themelib.color_to_type(set_fg_color[100])? == .whitespace
	assert themelib.color_to_type(set_fg_color[101])? == .identifier
	assert themelib.color_to_type(set_fg_color[102])? == .whitespace
	assert themelib.color_to_type(set_fg_color[103])? == .identifier
	assert themelib.color_to_type(set_fg_color[104])? == .whitespace
	assert themelib.color_to_type(set_fg_color[105])? == .number
	assert themelib.color_to_type(set_fg_color[106])? == .whitespace
	assert themelib.color_to_type(set_fg_color[107])? == .identifier
	assert themelib.color_to_type(set_fg_color[108])? == .whitespace
	assert themelib.color_to_type(set_fg_color[109])? == .identifier
	assert themelib.color_to_type(set_fg_color[110])? == .whitespace
	assert themelib.color_to_type(set_fg_color[111])? == .identifier

	assert set_fg_color[112] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[113])? == .identifier
	assert themelib.color_to_type(set_fg_color[114])? == .whitespace
	assert themelib.color_to_type(set_fg_color[115])? == .identifier
	assert themelib.color_to_type(set_fg_color[116])? == .whitespace
	assert themelib.color_to_type(set_fg_color[117])? == .identifier
	assert themelib.color_to_type(set_fg_color[118])? == .whitespace
	assert themelib.color_to_type(set_fg_color[119])? == .number
	assert themelib.color_to_type(set_fg_color[120])? == .whitespace
	assert themelib.color_to_type(set_fg_color[121])? == .identifier
	assert themelib.color_to_type(set_fg_color[122])? == .whitespace
	assert themelib.color_to_type(set_fg_color[123])? == .identifier
	assert themelib.color_to_type(set_fg_color[124])? == .whitespace
	assert themelib.color_to_type(set_fg_color[125])? == .identifier

	assert set_fg_color[126] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[127])? == .identifier
	assert themelib.color_to_type(set_fg_color[127])? == .identifier
	assert themelib.color_to_type(set_fg_color[128])? == .whitespace
	assert themelib.color_to_type(set_fg_color[129])? == .identifier
	assert themelib.color_to_type(set_fg_color[130])? == .whitespace
	assert themelib.color_to_type(set_fg_color[131])? == .identifier
	assert themelib.color_to_type(set_fg_color[132])? == .whitespace
	assert themelib.color_to_type(set_fg_color[133])? == .number
	assert themelib.color_to_type(set_fg_color[134])? == .whitespace
	assert themelib.color_to_type(set_fg_color[135])? == .identifier
	assert themelib.color_to_type(set_fg_color[136])? == .whitespace
	assert themelib.color_to_type(set_fg_color[137])? == .identifier
	assert themelib.color_to_type(set_fg_color[138])? == .whitespace
	assert themelib.color_to_type(set_fg_color[139])? == .identifier

	assert drawn_text[0] == DrawnText{ x: 1, y: 0, data: "5" }
	assert drawn_text[14] == DrawnText{ x: 1, y: 1, data: "4" }
	assert drawn_text[28] == DrawnText{ x: 1, y: 2, data: "3" }
	assert drawn_text[42] == DrawnText{ x: 1, y: 3, data: "2" }
	assert drawn_text[56] == DrawnText{ x: 1, y: 4, data: "1" }
	assert drawn_text[70] == DrawnText{ x: 0, y: 5, data: "16" }
	assert drawn_text[84] == DrawnText{ x: 1, y: 6, data: "1" }
	assert drawn_text[98] == DrawnText{ x: 1, y: 7, data: "2" }
	assert drawn_text[112] == DrawnText{ x: 1, y: 8, data: "3" }
	assert drawn_text[126] == DrawnText{ x: 1, y: 9, data: "4" }

	drawn_text.clear()
	buf_view.draw(
		mut mock_ctx, buf, x, y,
		width, height, from_line_num,
		min_x, true, .normal, BufferCursor{ pos: CursorPos{ y: 13 } }
	) // toggle relative line numbers on

	assert drawn_text[0] == DrawnText{ x: 1, y: 0, data: "3" }
	assert drawn_text[14] == DrawnText{ x: 1, y: 1, data: "2" }
	assert drawn_text[28] == DrawnText{ x: 1, y: 2, data: "1" }
	assert drawn_text[42] == DrawnText{ x: 0, y: 3, data: "14" }
	assert drawn_text[56] == DrawnText{ x: 1, y: 4, data: "1" }
	assert drawn_text[70] == DrawnText{ x: 1, y: 5, data: "2" }
	assert drawn_text[84] == DrawnText{ x: 1, y: 6, data: "3" }
	assert drawn_text[98] == DrawnText{ x: 1, y: 7, data: "4" }
	assert drawn_text[112] == DrawnText{ x: 1, y: 8, data: "5" }
	assert drawn_text[126] == DrawnText{ x: 1, y: 9, data: "6" }

	drawn_text.clear()
	buf_view.draw(
		mut mock_ctx, buf, x, y,
		width, height, from_line_num,
		min_x, true, .normal,
		BufferCursor{ pos: CursorPos{ y: 18 } }
	) // toggle relative line numbers on

	assert drawn_text[0] == DrawnText{ x: 1, y: 0, data: "8" }
	assert drawn_text[14] == DrawnText{ x: 1, y: 1, data: "7" }
	assert drawn_text[28] == DrawnText{ x: 1, y: 2, data: "6" }
	assert drawn_text[42] == DrawnText{ x: 1, y: 3, data: "5" }
	assert drawn_text[56] == DrawnText{ x: 1, y: 4, data: "4" }
	assert drawn_text[70] == DrawnText{ x: 1, y: 5, data: "3" }
	assert drawn_text[84] == DrawnText{ x: 1, y: 6, data: "2" }
	assert drawn_text[98] == DrawnText{ x: 1, y: 7, data: "1" }
	assert drawn_text[112] == DrawnText{ x: 0, y: 8, data: "19" }
	assert drawn_text[126] == DrawnText{ x: 1, y: 9, data: "1" }
}

type DT = DrawnText

fn test_buffer_view_draws_lines_0_to_max_height_min_x_0_max_width_14() {
	mut drawn_text := []DrawnText{}
	mut drawn_text_ref := &drawn_text

	mut set_fg_color := []tui.Color{}
	mut set_fg_color_ref := &set_fg_color

	mut set_bg_color := []tui.Color{}
	mut set_bg_color_ref := &set_bg_color

	mut drawn_rect := []DrawnRect{}
	mut drawn_rect_ref := &drawn_rect

	mut mock_ctx := MockContextable{
		on_draw_cb: fn [mut drawn_text_ref] (x int, y int, text string) {
			drawn_text_ref << DrawnText{ x: x, y: y, data: text }
		}
		on_draw_rect_cb: fn [mut drawn_rect_ref] (x int, y int, width int, height int) {
			drawn_rect_ref << DrawnRect{ x: x, y: y, width: width, height: height }
		}
		on_set_fg_color_cb: fn [mut set_fg_color_ref] (c draw.Color) {
			set_fg_color_ref << tui.Color{ r: c.r, g: c.g, b: c.b }
		}
		on_set_bg_color_cb: fn [mut set_bg_color_ref] (c draw.Color) {
			set_bg_color_ref << tui.Color{ r: c.r, g: c.g, b: c.b }
		}
	}

	mut buf      := buffer.Buffer.new("", .legacy)
	for i in 0..3 { buf.lines << "${i} This is line ${i} in the document" }
	mut buf_view := BufferView.new([], 0)

	x := 0
	y := 0
	width := 14
	height := 4
	min_x := 0
	from_line_num := 0

	buf_view.draw(mut mock_ctx, buf, x, y, width, height, from_line_num, min_x, false, .normal, BufferCursor{})

	assert set_bg_color == [tui.Color{ 53, 53, 53 }, tui.Color{ 53, 53, 53 }]
	assert drawn_rect == [
		DrawnRect{ x: 2, y: 0, width: 13, height: 1 }
	]

	assert drawn_text.len == 24
	assert set_fg_color.len == 24

	line_num_fg_color := mock_ctx.theme().line_number_color

	// this is the line at the side being rendered
	assert set_fg_color[0] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[1])? == .number
	assert themelib.color_to_type(set_fg_color[2])? == .whitespace
	assert themelib.color_to_type(set_fg_color[3])? == .identifier
	assert themelib.color_to_type(set_fg_color[4])? == .whitespace
	assert themelib.color_to_type(set_fg_color[5])? == .identifier
	assert themelib.color_to_type(set_fg_color[6])? == .whitespace
	assert themelib.color_to_type(set_fg_color[7])? == .identifier

	// this is the line at the side being rendered
	assert set_fg_color[8] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[9])? == .number
	assert themelib.color_to_type(set_fg_color[10])? == .whitespace
	assert themelib.color_to_type(set_fg_color[11])? == .identifier
	assert themelib.color_to_type(set_fg_color[12])? == .whitespace
	assert themelib.color_to_type(set_fg_color[13])? == .identifier
	assert themelib.color_to_type(set_fg_color[14])? == .whitespace
	assert themelib.color_to_type(set_fg_color[15])? == .identifier

	// this is the line at the side being rendered
	assert set_fg_color[16] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[17])? == .number
	assert themelib.color_to_type(set_fg_color[18])? == .whitespace
	assert themelib.color_to_type(set_fg_color[19])? == .identifier
	assert themelib.color_to_type(set_fg_color[20])? == .whitespace
	assert themelib.color_to_type(set_fg_color[21])? == .identifier
	assert themelib.color_to_type(set_fg_color[22])? == .whitespace
	assert themelib.color_to_type(set_fg_color[23])? == .identifier

	line_one_expected_drawn_data := [
		DrawnText{ x: 0, y: 0, data: "1" }, DT{ x: 2, y: 0, data: "0" }, DT{ x: 3, y: 0, data: " " },
		DT{ x: 4, y: 0, data: "This" }, DT{ x: 8, y: 0, data: " " }, DT{ x: 9, y: 0, data: "is" },
		DT{ x: 11, y: 0, data: " " }, DT{ x: 12, y: 0, data: "li" }
	]
	assert drawn_text[..8] == line_one_expected_drawn_data

	line_two_expected_drawn_data := [
		DrawnText{ x: 0, y: 1, data: "2" }, DT{ x: 2, y: 1, data: "1" }, DT{ x: 3, y: 1, data: " " },
		DT{ x: 4, y: 1, data: "This" }, DT{ x: 8, y: 1, data: " " }, DT{ x: 9, y: 1, data: "is" },
		DT{ x: 11, y: 1, data: " " }, DT{ x: 12, y: 1, data: "li" }
	]
	assert drawn_text[8..16] == line_two_expected_drawn_data

	line_three_expected_drawn_data := [
		DrawnText{ x: 0, y: 2, data: "3" }, DT{ x: 2, y: 2, data: "2" }, DT{ x: 3, y: 2, data: " " },
		DT{ x: 4, y: 2, data: "This" }, DT{ x: 8, y: 2, data: " " }, DT{ x: 9, y: 2, data: "is" },
		DT{ x: 11, y: 2, data: " " }, DT{ x: 12, y: 2, data: "li" }
	]
	assert drawn_text[16..24] == line_three_expected_drawn_data
}

fn test_buffer_view_draws_lines_0_to_max_height_min_x_4_max_width_56() {
	mut drawn_text := []DrawnText{}
	mut drawn_text_ref := &drawn_text

	mut set_fg_color := []tui.Color{}
	mut set_fg_color_ref := &set_fg_color

	mut set_bg_color := []tui.Color{}
	mut set_bg_color_ref := &set_bg_color

	mut drawn_rect := []DrawnRect{}
	mut drawn_rect_ref := &drawn_rect

	mut mock_ctx := MockContextable{
		on_draw_cb: fn [mut drawn_text_ref] (x int, y int, text string) {
			drawn_text_ref << DrawnText{ x: x, y: y, data: text }
		}
		on_draw_rect_cb: fn [mut drawn_rect_ref] (x int, y int, width int, height int) {
			drawn_rect_ref << DrawnRect{ x: x, y: y, width: width, height: height }
		}
		on_set_fg_color_cb: fn [mut set_fg_color_ref] (c draw.Color) {
			set_fg_color_ref << tui.Color{ r: c.r, g: c.g, b: c.b }
		}
		on_set_bg_color_cb: fn [mut set_bg_color_ref] (c draw.Color) {
			set_bg_color_ref << tui.Color{ r: c.r, g: c.g, b: c.b }
		}
	}

	mut buf      := buffer.Buffer.new("", .legacy)
	for i in 0..3 { buf.lines << "${i} This is line ${i} in the document" }
	mut buf_view := BufferView.new([], 0)

	x := 0
	y := 0
	width := 56
	height := 4
	min_x := 4
	from_line_num := 0

	buf_view.draw(mut mock_ctx, buf, x, y, width, height, from_line_num, min_x, false, .normal, BufferCursor{})

	assert set_bg_color == [tui.Color{ 53, 53, 53 }, tui.Color{ 53, 53, 53 }]
	assert drawn_rect == [
		DrawnRect{ x: 2, y: 0, width: 55, height: 1 }
	]

	assert drawn_text.len == 42
	assert set_fg_color.len == 42

	line_num_fg_color := mock_ctx.theme().line_number_color

	// this is the line at the side being rendered
	assert set_fg_color[0] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[1])? == .identifier
	assert themelib.color_to_type(set_fg_color[2])? == .whitespace
	assert themelib.color_to_type(set_fg_color[3])? == .identifier
	assert themelib.color_to_type(set_fg_color[4])? == .whitespace
	assert themelib.color_to_type(set_fg_color[5])? == .identifier
	assert themelib.color_to_type(set_fg_color[6])? == .whitespace
	assert themelib.color_to_type(set_fg_color[7])? == .number
	assert themelib.color_to_type(set_fg_color[8])? == .whitespace
	assert themelib.color_to_type(set_fg_color[9])? == .identifier
	assert themelib.color_to_type(set_fg_color[10])? == .whitespace
	assert themelib.color_to_type(set_fg_color[11])? == .identifier
	assert themelib.color_to_type(set_fg_color[12])? == .whitespace
	assert themelib.color_to_type(set_fg_color[13])? == .identifier

	assert set_fg_color[14] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[15])? == .identifier
	assert themelib.color_to_type(set_fg_color[16])? == .whitespace
	assert themelib.color_to_type(set_fg_color[17])? == .identifier
	assert themelib.color_to_type(set_fg_color[18])? == .whitespace
	assert themelib.color_to_type(set_fg_color[19])? == .identifier
	assert themelib.color_to_type(set_fg_color[20])? == .whitespace
	assert themelib.color_to_type(set_fg_color[21])? == .number
	assert themelib.color_to_type(set_fg_color[22])? == .whitespace
	assert themelib.color_to_type(set_fg_color[23])? == .identifier
	assert themelib.color_to_type(set_fg_color[24])? == .whitespace
	assert themelib.color_to_type(set_fg_color[25])? == .identifier
	assert themelib.color_to_type(set_fg_color[26])? == .whitespace
	assert themelib.color_to_type(set_fg_color[27])? == .identifier

	assert set_fg_color[28] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[29])? == .identifier
	assert themelib.color_to_type(set_fg_color[30])? == .whitespace
	assert themelib.color_to_type(set_fg_color[31])? == .identifier
	assert themelib.color_to_type(set_fg_color[32])? == .whitespace
	assert themelib.color_to_type(set_fg_color[33])? == .identifier
	assert themelib.color_to_type(set_fg_color[34])? == .whitespace
	assert themelib.color_to_type(set_fg_color[35])? == .number
	assert themelib.color_to_type(set_fg_color[36])? == .whitespace
	assert themelib.color_to_type(set_fg_color[37])? == .identifier
	assert themelib.color_to_type(set_fg_color[38])? == .whitespace
	assert themelib.color_to_type(set_fg_color[39])? == .identifier
	assert themelib.color_to_type(set_fg_color[40])? == .whitespace
	assert themelib.color_to_type(set_fg_color[41])? == .identifier

	line_one_expected_drawn_data := [
		DrawnText{ x: 0, y: 0, data: "1" }, DT{ x: 2, y: 0, data: "is" }, DT{ x: 4, y: 0, data: " " },
		DT{ x: 5, y: 0, data: "is" }, DT{ x: 7, y: 0, data: " " }, DT{ x: 8, y: 0, data: "line" },
		DT{ x: 12, y: 0, data: " " }, DT{ x: 13, y: 0, data: "0" }, DT{ x: 14, y: 0, data: " " },
		DT{ x: 15, y: 0, data: "in" }, DT{ x: 17, y: 0, data: " " }, DT{ x: 18, y: 0, data: "the" },
		DT{ x: 21, y: 0, data: " " }, DT{ x: 22, y: 0, data: "document" }
	]
	assert drawn_text[..14] == line_one_expected_drawn_data

	line_two_expected_drawn_data := [
		DrawnText{ x: 0, y: 1, data: "2" }, DT{ x: 2, y: 1, data: "is" }, DT{ x: 4, y: 1, data: " " },
		DT{ x: 5, y: 1, data: "is" }, DT{ x: 7, y: 1, data: " " }, DT{ x: 8, y: 1, data: "line" },
		DT{ x: 12, y: 1, data: " " }, DT{ x: 13, y: 1, data: "1" }, DT{ x: 14, y: 1, data: " " },
		DT{ x: 15, y: 1, data: "in" }, DT{ x: 17, y: 1, data: " " }, DT{ x: 18, y: 1, data: "the" },
		DT{ x: 21, y: 1, data: " " }, DT{ x: 22, y: 1, data: "document" }
	]
	assert drawn_text[14..28] == line_two_expected_drawn_data

	line_three_expected_drawn_data := [
		DrawnText{ x: 0, y: 2, data: "3" }, DT{ x: 2, y: 2, data: "is" }, DT{ x: 4, y: 2, data: " " },
		DT{ x: 5, y: 2, data: "is" }, DT{ x: 7, y: 2, data: " " }, DT{ x: 8, y: 2, data: "line" },
		DT{ x: 12, y: 2, data: " " }, DT{ x: 13, y: 2, data: "2" }, DT{ x: 14, y: 2, data: " " },
		DT{ x: 15, y: 2, data: "in" }, DT{ x: 17, y: 2, data: " " }, DT{ x: 18, y: 2, data: "the" },
		DT{ x: 21, y: 2, data: " " }, DT{ x: 22, y: 2, data: "document" }
	]
	assert drawn_text[28..42] == line_three_expected_drawn_data
}

fn test_buffer_view_draws_lines_0_to_max_height_min_x_21_max_width_56() {
	mut drawn_text := []DrawnText{}
	mut drawn_text_ref := &drawn_text

	mut set_fg_color := []tui.Color{}
	mut set_fg_color_ref := &set_fg_color

	mut set_bg_color := []tui.Color{}
	mut set_bg_color_ref := &set_bg_color

	mut drawn_rect := []DrawnRect{}
	mut drawn_rect_ref := &drawn_rect

	mut mock_ctx := MockContextable{
		on_draw_cb: fn [mut drawn_text_ref] (x int, y int, text string) {
			drawn_text_ref << DrawnText{ x: x, y: y, data: text }
		}
		on_draw_rect_cb: fn [mut drawn_rect_ref] (x int, y int, width int, height int) {
			drawn_rect_ref << DrawnRect{ x: x, y: y, width: width, height: height }
		}
		on_set_fg_color_cb: fn [mut set_fg_color_ref] (c draw.Color) {
			set_fg_color_ref << tui.Color{ r: c.r, g: c.g, b: c.b }
		}
		on_set_bg_color_cb: fn [mut set_bg_color_ref] (c draw.Color) {
			set_bg_color_ref << tui.Color{ r: c.r, g: c.g, b: c.b }
		}
	}

	mut buf      := buffer.Buffer.new("", .legacy)
	for i in 0..3 { buf.lines << "${i} This is line ${i} in the document" }
	mut buf_view := BufferView.new([], 0)

	x := 0
	y := 0
	width := 56
	height := 4
	min_x := 21
	from_line_num := 0

	buf_view.draw(mut mock_ctx, buf, x, y, width, height, from_line_num, min_x, false, .normal, BufferCursor{})

	assert set_bg_color == [tui.Color{ 53, 53, 53 }, tui.Color{ 53, 53, 53 }]
	assert drawn_rect == [
		DrawnRect{ x: 2, y: 0, width: 55, height: 1 }
	]

	assert drawn_text.len == 12
	assert set_fg_color.len == 12

	line_num_fg_color := mock_ctx.theme().line_number_color

	// this is the line at the side being rendered
	assert set_fg_color[0] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[1])? == .identifier
	assert themelib.color_to_type(set_fg_color[2])? == .whitespace
	assert themelib.color_to_type(set_fg_color[3])? == .identifier

	assert set_fg_color[4] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[5])? == .identifier
	assert themelib.color_to_type(set_fg_color[6])? == .whitespace
	assert themelib.color_to_type(set_fg_color[7])? == .identifier

	assert set_fg_color[8] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[9])? == .identifier
	assert themelib.color_to_type(set_fg_color[10])? == .whitespace
	assert themelib.color_to_type(set_fg_color[11])? == .identifier

	line_one_expected_drawn_data := [
		DrawnText{ x: 0, y: 0, data: "1" }, DT{ x: 2, y: 0, data: "he" },
		DT{ x: 4, y: 0, data: " " }, DT{ x: 5, y: 0, data: "document" }
	]
	assert drawn_text[..4] == line_one_expected_drawn_data

	line_two_expected_drawn_data := [
		DrawnText{ x: 0, y: 1, data: "2" }, DT{ x: 2, y: 1, data: "he" },
		DT{ x: 4, y: 1, data: " " }, DT{ x: 5, y: 1, data: "document" }
	]
	assert drawn_text[4..8] == line_two_expected_drawn_data

	line_three_expected_drawn_data := [
		DrawnText{ x: 0, y: 2, data: "3" }, DT{ x: 2, y: 2, data: "he" },
		DT{ x: 4, y: 2, data: " " }, DT{ x: 5, y: 2, data: "document" }
	]
	assert drawn_text[8..12] == line_three_expected_drawn_data
}

fn test_buffer_view_draws_lines_0_to_max_height_min_x_21_max_width_6() {
	mut drawn_text := []DrawnText{}
	mut drawn_text_ref := &drawn_text

	mut set_fg_color := []tui.Color{}
	mut set_fg_color_ref := &set_fg_color

	mut set_bg_color := []tui.Color{}
	mut set_bg_color_ref := &set_bg_color

	mut drawn_rect := []DrawnRect{}
	mut drawn_rect_ref := &drawn_rect

	mut mock_ctx := MockContextable{
		on_draw_cb: fn [mut drawn_text_ref] (x int, y int, text string) {
			drawn_text_ref << DrawnText{ x: x, y: y, data: text }
		}
		on_draw_rect_cb: fn [mut drawn_rect_ref] (x int, y int, width int, height int) {
			drawn_rect_ref << DrawnRect{ x: x, y: y, width: width, height: height }
		}
		on_set_fg_color_cb: fn [mut set_fg_color_ref] (c draw.Color) {
			set_fg_color_ref << tui.Color{ r: c.r, g: c.g, b: c.b }
		}
		on_set_bg_color_cb: fn [mut set_bg_color_ref] (c draw.Color) {
			set_bg_color_ref << tui.Color{ r: c.r, g: c.g, b: c.b }
		}
	}

	mut buf      := buffer.Buffer.new("", .legacy)
	for i in 0..3 { buf.lines << "${i} This is line ${i} in the document" }
	mut buf_view := BufferView.new([], 0)

	x := 0
	y := 0
	width := 12
	height := 4
	min_x := 21
	from_line_num := 0

	buf_view.draw(mut mock_ctx, buf, x, y, width, height, from_line_num, min_x, false, .normal, BufferCursor{})

	assert set_bg_color == [tui.Color{ 53, 53, 53 }, tui.Color{ 53, 53, 53 }]
	assert drawn_rect == [
		DrawnRect{ x: 2, y: 0, width: 11, height: 1 }
	]

	assert drawn_text.len == 12
	assert set_fg_color.len == 12

	line_num_fg_color := mock_ctx.theme().line_number_color

	// this is the line at the side being rendered
	assert set_fg_color[0] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[1])? == .identifier
	assert themelib.color_to_type(set_fg_color[2])? == .whitespace
	assert themelib.color_to_type(set_fg_color[3])? == .identifier

	assert set_fg_color[4] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[5])? == .identifier
	assert themelib.color_to_type(set_fg_color[6])? == .whitespace
	assert themelib.color_to_type(set_fg_color[7])? == .identifier

	assert set_fg_color[8] == line_num_fg_color
	assert themelib.color_to_type(set_fg_color[9])? == .identifier
	assert themelib.color_to_type(set_fg_color[10])? == .whitespace
	assert themelib.color_to_type(set_fg_color[11])? == .identifier

	line_one_expected_drawn_data := [
		DrawnText{ x: 0, y: 0, data: "1" }, DT{ x: 2, y: 0, data: "he" },
		DT{ x: 4, y: 0, data: " " }, DT{ x: 5, y: 0, data: "documen" }
	]
	assert drawn_text[..4] == line_one_expected_drawn_data

	line_two_expected_drawn_data := [
		DrawnText{ x: 0, y: 1, data: "2" }, DT{ x: 2, y: 1, data: "he" },
		DT{ x: 4, y: 1, data: " " }, DT{ x: 5, y: 1, data: "documen" }
	]
	assert drawn_text[4..8] == line_two_expected_drawn_data

	line_three_expected_drawn_data := [
		DrawnText{ x: 0, y: 2, data: "3" }, DT{ x: 2, y: 2, data: "he" },
		DT{ x: 4, y: 2, data: " " }, DT{ x: 5, y: 2, data: "documen" }
	]
	assert drawn_text[8..12] == line_three_expected_drawn_data
}

fn test_render_segment_in_visual_mode_specific_selection_is_all_of_current_line() {
	mut drawn_text := []ColoredDrawnText{}
	mut drawn_text_ref := &drawn_text

	mut mock_ctx := MockColorContextable{
		on_draw_cb: fn [
			mut drawn_text_ref
		] (x int, y int, text string, active_fg_color tui.Color, active_bg_color ?tui.Color) {
			drawn_text_ref << ColoredDrawnText{
				x, y, text, active_fg_color, active_bg_color
			}
		}
		on_draw_rect_cb: fn (x int, y int, w int, h int) {}
	}

	segment_to_render := "singlelargeorlongtokentorender"
	segment_bounds    := TokenBounds{ start: 10, end: 40 }
	fg_color          := tui.Color{ 110, 110, 110 }
	// NOTE(tauraamui) [18/06/2025]: the coords in this case are mostly irrelevant
	x                 := 0
	y                 := 0
	render_segment_in_visual_mode(mut mock_ctx, segment_bounds, segment_to_render, fg_color, x, y, SelectionSpan{ full: true })

	theme_selection_bg_color := mock_ctx.theme().selection_highlight_color

	assert drawn_text == [
		ColoredDrawnText{ x: 0, y: 0, data: "singlelargeorlongtokentorender", fg_color: fg_color, bg_color: theme_selection_bg_color }
	]
}

fn test_render_segment_in_visual_mode_specific_selection_is_prior_to_segment_on_line_selection_starts_at_start_of_line() {
	mut drawn_text := []ColoredDrawnText{}
	mut drawn_text_ref := &drawn_text

	mut mock_ctx := MockColorContextable{
		on_draw_cb: fn [
			mut drawn_text_ref
		] (x int, y int, text string, active_fg_color tui.Color, active_bg_color ?tui.Color) {
			drawn_text_ref << ColoredDrawnText{
				x, y, text, active_fg_color, active_bg_color
			}
		}
		on_draw_rect_cb: fn (x int, y int, w int, h int) {}
	}

	segment_to_render := "singlelargeorlongtokentorender"
	segment_bounds    := TokenBounds{ start: 20, end: 50 }
	fg_color          := tui.Color{ 110, 110, 110 }
	// NOTE(tauraamui) [18/06/2025]: the coords in this case are mostly irrelevant
	x                 := 0
	y                 := 0
	render_segment_in_visual_mode(
		mut mock_ctx, segment_bounds,
		segment_to_render, fg_color,
		x, y, SelectionSpan{ min_x: 0, max_x: 15 }
	)

	theme_selection_bg_color := ?tui.Color(none)
	assert drawn_text == [
		ColoredDrawnText{ x: 0, y: 0, data: "singlelargeorlongtokentorender", fg_color: fg_color, bg_color: theme_selection_bg_color }
	]
}

fn test_render_segment_in_visual_mode_specific_selection_is_past_to_segment_on_line_selection_ends_at_end_of_line() {
	mut drawn_text := []ColoredDrawnText{}
	mut drawn_text_ref := &drawn_text

	mut mock_ctx := MockColorContextable{
		on_draw_cb: fn [
			mut drawn_text_ref
		] (x int, y int, text string, active_fg_color tui.Color, active_bg_color ?tui.Color) {
			drawn_text_ref << ColoredDrawnText{
				x, y, text, active_fg_color, active_bg_color
			}
		}
		on_draw_rect_cb: fn (x int, y int, w int, h int) {}
	}

	segment_to_render := "singlelargeorlongtokentorender"
	segment_bounds    := TokenBounds{ start: 20, end: 50 }
	fg_color          := tui.Color{ 110, 110, 110 }
	// NOTE(tauraamui) [18/06/2025]: the coords in this case are mostly irrelevant
	x                 := 0
	y                 := 0
	render_segment_in_visual_mode(
		mut mock_ctx, segment_bounds,
		segment_to_render, fg_color,
		x, y, SelectionSpan{ min_x: 55, max_x: 75 }
	)

	theme_selection_bg_color := ?tui.Color(none)
	assert drawn_text == [
		ColoredDrawnText{ x: 0, y: 0, data: "singlelargeorlongtokentorender", fg_color: fg_color, bg_color: theme_selection_bg_color }
	]
}

fn test_render_segment_in_visual_mode_specific_selection_starts_and_ends_within_segment() {
	mut drawn_text := []ColoredDrawnText{}
	mut drawn_text_ref := &drawn_text

	mut mock_ctx := MockColorContextable{
		on_draw_cb: fn [
			mut drawn_text_ref
		] (x int, y int, text string, active_fg_color tui.Color, active_bg_color ?tui.Color) {
			drawn_text_ref << ColoredDrawnText{
				x, y, text, active_fg_color, active_bg_color
			}
		}
		on_draw_rect_cb: fn (x int, y int, w int, h int) {}
	}

	segment_to_render := "singlelargeorlongtokentorender"
	segment_bounds    := TokenBounds{ start: 20, end: 50 }
	fg_color          := tui.Color{ 110, 110, 110 }
	// NOTE(tauraamui) [18/06/2025]: the coords in this case are mostly irrelevant
	x                 := 20
	y                 := 0
	render_segment_in_visual_mode(
		mut mock_ctx, segment_bounds,
		segment_to_render, fg_color,
		x, y, SelectionSpan{ min_x: 35, max_x: 45 }
	)

	theme_selection_bg_color := mock_ctx.theme().selection_highlight_color
	assert drawn_text == [
		ColoredDrawnText{
			x: 20, y: 0, data: "singlelargeorlo", fg_color: fg_color, bg_color: ?tui.Color(none)
		},
		ColoredDrawnText{
			x: 35, y: 0, data: "ngtokentor", fg_color: tui.Color{ 0, 0, 0 }, bg_color: theme_selection_bg_color
		}
		ColoredDrawnText{
			x: 45, y: 0, data: "ender", fg_color: fg_color, bg_color: ?tui.Color(none)
		}
	]
}

fn test_render_segment_in_visual_mode_specific_selection_overlaps_first_half_of_segment() {
	mut drawn_text := []ColoredDrawnText{}
	mut drawn_text_ref := &drawn_text

	mut mock_ctx := MockColorContextable{
		on_draw_cb: fn [
			mut drawn_text_ref
		] (x int, y int, text string, active_fg_color tui.Color, active_bg_color ?tui.Color) {
			drawn_text_ref << ColoredDrawnText{
				x, y, text, active_fg_color, active_bg_color
			}
		}
		on_draw_rect_cb: fn (x int, y int, w int, h int) {}
	}

	segment_to_render := "singlelargeorlongtokentorender"
	segment_bounds    := TokenBounds{ start: 20, end: 50 }
	fg_color          := tui.Color{ 110, 110, 110 }
	// NOTE(tauraamui) [18/06/2025]: the coords in this case are mostly irrelevant
	x                 := 20
	y                 := 0
	render_segment_in_visual_mode(
		mut mock_ctx, segment_bounds,
		segment_to_render, fg_color,
		x, y, SelectionSpan{ min_x: 0, max_x: 35 }
	)

	theme_selection_bg_color := mock_ctx.theme().selection_highlight_color
	assert drawn_text == [
		ColoredDrawnText{
			x: 20, y: 0, data: "singlelargeorlo", fg_color: tui.Color{ 0, 0, 0 }, bg_color: theme_selection_bg_color
		},
		ColoredDrawnText{
			x: 35, y: 0, data: "ngtokentorender", fg_color: fg_color, bg_color: ?tui.Color(none)
		}
	]
}

fn test_render_segment_in_visual_mode_specific_selection_overlaps_second_half_of_segment() {
	mut drawn_text := []ColoredDrawnText{}
	mut drawn_text_ref := &drawn_text

	mut mock_ctx := MockColorContextable{
		on_draw_cb: fn [
			mut drawn_text_ref
		] (x int, y int, text string, active_fg_color tui.Color, active_bg_color ?tui.Color) {
			drawn_text_ref << ColoredDrawnText{
				x, y, text, active_fg_color, active_bg_color
			}
		}
		on_draw_rect_cb: fn (x int, y int, w int, h int) {}
	}

	segment_to_render := "singlelargeorlongtokentorender"
	segment_bounds    := TokenBounds{ start: 20, end: 50 }
	fg_color          := tui.Color{ 110, 110, 110 }
	// NOTE(tauraamui) [18/06/2025]: the coords in this case are mostly irrelevant
	x                 := 20
	y                 := 0
	render_segment_in_visual_mode(
		mut mock_ctx, segment_bounds,
		segment_to_render, fg_color,
		x, y, SelectionSpan{ min_x: 35, max_x: 70 }
	)

	theme_selection_bg_color := mock_ctx.theme().selection_highlight_color
	assert drawn_text == [
		ColoredDrawnText{
			x: 20, y: 0, data: "singlelargeorlo", fg_color: fg_color, bg_color: ?tui.Color(none)
		},
		ColoredDrawnText{
			x: 35, y: 0, data: "ngtokentorender", fg_color: tui.Color{ 0, 0, 0 }, bg_color: theme_selection_bg_color
		}
	]
}

/*
fn test_render_segment_in_visual_mode_specific_selection_covers_all_of_segment() {
	mut drawn_text := []ColoredDrawnText{}
	mut drawn_text_ref := &drawn_text

	mut mock_ctx := MockColorContextable{
		on_draw_cb: fn [
			mut drawn_text_ref
		] (x int, y int, text string, active_fg_color tui.Color, active_bg_color ?tui.Color) {
			drawn_text_ref << ColoredDrawnText{
				x, y, text, active_fg_color, active_bg_color
			}
		}
		on_draw_rect_cb: fn (x int, y int, w int, h int) {}
	}

	segment_to_render := "singlelargeorlongtokentorender"
	segment_bounds    := TokenBounds{ start: 10, end: 40 }
	fg_color          := tui.Color{ 110, 110, 110 }
	// NOTE(tauraamui) [18/06/2025]: the coords in this case are mostly irrelevant
	x                 := 0
	y                 := 0
	render_segment_in_visual_mode(
		mut mock_ctx, segment_bounds,
		segment_to_render, fg_color,
		x, y, SelectionSpan{ min_x: 5, max_x: 45 }
	)

	theme_selection_bg_color := mock_ctx.theme().selection_highlight_color

	assert drawn_text == [
		ColoredDrawnText{ x: 0, y: 0, data: "singlelargeorlongtokentorender", fg_color: fg_color, bg_color: theme_selection_bg_color }
	]
}
*/

fn test_resolve_token_bounds_min_x_is_0() {
	token_start := 0
	token_end   := 13
	min_x       := 0

	assert resolve_token_bounds(token_start, token_end, min_x)! == TokenBounds{
		start: token_start
		end:   token_end
	}
}

fn test_resolve_token_bounds_min_x_is_5() {
	token_start := 0
	token_end   := 13
	min_x       := 5

	assert resolve_token_bounds(token_start, token_end, min_x)! == TokenBounds{
		start: 5
		end:   token_end
	}
}

struct MockColorContextable {
mut:
	on_draw_cb         fn (x int, y int, text string, active_fg_color tui.Color, active_bg_color ?tui.Color) @[required]
	on_draw_rect_cb    fn (x int, y int, width int, height int) @[required]
	active_fg_color tui.Color
	active_bg_color ?tui.Color
}

fn (mockctx MockColorContextable) theme() themelib.Theme {
	return themelib.Theme.new("test") or { panic("error occurred loading theme: ${err}") }
}

fn (mockctx MockColorContextable) render_debug() bool { return false }

fn (mockctx MockColorContextable) rate_limit_draws() bool {
	return false
}

fn (mockctx MockColorContextable) window_width() int {
	return 0
}

fn (mockctx MockColorContextable) window_height() int {
	return 0
}

fn (mockctx MockColorContextable) set_cursor_position(x int, y int) {}

fn (mockctx MockColorContextable) set_cursor_to_block() {}

fn (mockctx MockColorContextable) set_cursor_to_underline() {}

fn (mockctx MockColorContextable) set_cursor_to_vertical_bar() {}

fn (mockctx MockColorContextable) show_cursor() {}

fn (mockctx MockColorContextable) hide_cursor() {}

fn (mockctx MockColorContextable) draw_text(x int, y int, text string) {
	mockctx.on_draw_cb(x, y, text, mockctx.active_fg_color, mockctx.active_bg_color)
}

fn (mockctx MockColorContextable) write(c string) {}

fn (mockctx MockColorContextable) draw_rect(x int, y int, width int, height int) {
	if mockctx.on_draw_rect_cb == unsafe { nil } { return }
	mockctx.on_draw_rect_cb(x, y, width, height)
}

fn (mockctx MockColorContextable) draw_point(x int, y int) {}

fn (mut mockctx MockColorContextable) set_color(c draw.Color) {
	mockctx.active_fg_color = tui.Color{ r: c.r, g: c.g, b: c.b }
}

fn (mut mockctx MockColorContextable) set_bg_color(c draw.Color) {
	mockctx.active_bg_color = tui.Color{ r: c.r, g: c.g, b: c.b }
}

fn (mockctx MockColorContextable) revert_bg_color() {}

fn (mut mockctx MockColorContextable) reset_color() {
	mockctx.active_fg_color = tui.Color{}
}

fn (mut mockctx MockColorContextable) reset_bg_color() {
	mockctx.active_bg_color = ?tui.Color(none)
}

fn (mockctx MockColorContextable) bold() {}

fn (mockctx MockColorContextable) set_style(s draw.Style) {}

fn (mockctx MockColorContextable) clear_style() {}

fn (mockctx MockColorContextable) reset() {}

fn (mockctx MockColorContextable) run() ! {}

fn (mockctx MockColorContextable) clear() {}

fn (mockctx MockColorContextable) flush() {}

struct MockContextable {
mut:
	on_draw_cb         fn (x int, y int, text string)
	on_draw_rect_cb    fn (x int, y int, width int, height int)
	on_set_fg_color_cb fn (c draw.Color)
	on_set_bg_color_cb fn (c draw.Color)
}

fn (mockctx MockContextable) theme() themelib.Theme {
	return themelib.Theme.new("test") or { panic("error occurred loading theme: ${err}") }
}

fn (mockctx MockContextable) render_debug() bool { return false }

fn (mockctx MockContextable) rate_limit_draws() bool {
	return false
}

fn (mockctx MockContextable) window_width() int {
	return 0
}

fn (mockctx MockContextable) window_height() int {
	return 0
}

fn (mockctx MockContextable) set_cursor_position(x int, y int) {}

fn (mockctx MockContextable) set_cursor_to_block() {}

fn (mockctx MockContextable) set_cursor_to_underline() {}

fn (mockctx MockContextable) set_cursor_to_vertical_bar() {}

fn (mockctx MockContextable) show_cursor() {}

fn (mockctx MockContextable) hide_cursor() {}

fn (mut mockctx MockContextable) draw_text(x int, y int, text string) {
	mockctx.on_draw_cb(x, y, text)
}

fn (mockctx MockContextable) write(c string) {}

fn (mockctx MockContextable) draw_rect(x int, y int, width int, height int) {
	if mockctx.on_draw_rect_cb == unsafe { nil } { return }
	mockctx.on_draw_rect_cb(x, y, width, height)
}

fn (mockctx MockContextable) draw_point(x int, y int) {}

fn (mockctx MockContextable) set_color(c draw.Color) {
	if mockctx.on_set_fg_color_cb == unsafe { nil } { return }
	mockctx.on_set_fg_color_cb(c)
}

fn (mockctx MockContextable) set_bg_color(c draw.Color) {
	if mockctx.on_set_bg_color_cb == unsafe { nil } { return }
	mockctx.on_set_bg_color_cb(c)
}

fn (mockctx MockContextable) revert_bg_color() {}

fn (mockctx MockContextable) reset_color() {}

fn (mockctx MockContextable) reset_bg_color() {}

fn (mockctx MockContextable) bold() {}

fn (mockctx MockContextable) set_style(s draw.Style) {}

fn (mockctx MockContextable) clear_style() {}

fn (mockctx MockContextable) reset() {}

fn (mockctx MockContextable) run() ! {}

fn (mockctx MockContextable) clear() {}

fn (mockctx MockContextable) flush() {}
