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

module ui

import lib.buffer
import lib.draw

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

fn test_buffer_view_draws_lines_0_to_max_height() {
	mut drawn_text := []DrawnText{}
	mut drawn_text_ref := &drawn_text

	mut drawn_rect := []DrawnRect{}
	mut drawn_rect_ref := &drawn_rect

	mut mock_ctx := MockContextable{
		on_draw_cb: fn [mut drawn_text_ref] (x int, y int, text string) {
			drawn_text_ref << DrawnText{ x: x, y: y, data: text }
		}
		on_draw_rect_cb: fn [mut drawn_rect_ref] (x int, y int, width int, height int) {
			drawn_rect_ref << DrawnRect{ x: x, y: y, width: width, height: height }
		}
	}

	mut buf := buffer.Buffer.new("", false)
	for i in 0..20 { buf.lines << "${i} This is line ${i} in the document" }
	buf_view := BufferView.new(&buf)

	x := 0
	y := 0
	width := 100
	height := 10
	min_x := 0
	from_line_num := 0

	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num, min_x, 0)

	assert drawn_rect == [
		DrawnRect{ x: 4, y: 1, width: 97, height: 1 }
	]

	assert drawn_text == [
		DrawnText{ x: 2, y: 1, data:  "1" },
		DrawnText{ x: 4, y: 1, data:  "0 This is line 0 in the document" },
		DrawnText{ x: 2, y: 2, data:  "2" },
		DrawnText{ x: 4, y: 2, data:  "1 This is line 1 in the document" },
		DrawnText{ x: 2, y: 3, data:  "3" },
		DrawnText{ x: 4, y: 3, data:  "2 This is line 2 in the document" },
		DrawnText{ x: 2, y: 4, data:  "4" },
		DrawnText{ x: 4, y: 4, data:  "3 This is line 3 in the document" },
		DrawnText{ x: 2, y: 5, data:  "5" },
		DrawnText{ x: 4, y: 5, data:  "4 This is line 4 in the document" },
		DrawnText{ x: 2, y: 6, data:  "6" },
		DrawnText{ x: 4, y: 6, data:  "5 This is line 5 in the document" },
		DrawnText{ x: 2, y: 7, data:  "7" },
		DrawnText{ x: 4, y: 7, data:  "6 This is line 6 in the document" },
		DrawnText{ x: 2, y: 8, data:  "8" },
		DrawnText{ x: 4, y: 8, data:  "7 This is line 7 in the document" },
		DrawnText{ x: 2, y: 9, data:  "9" },
		DrawnText{ x: 4, y: 9, data:  "8 This is line 8 in the document" },
		DrawnText{ x: 1, y: 10, data:  "10" },
		DrawnText{ x: 4, y: 10, data: "9 This is line 9 in the document" }
	]
}

fn test_buffer_view_draws_lines_0_to_max_height_2() {
	mut drawn_text := []DrawnText{}
	mut drawn_text_ref := &drawn_text

	mut set_fg_color := []draw.Color{}
	mut set_fg_color_ref := &set_fg_color

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
			set_fg_color_ref << c
		}
	}

	mut buf := buffer.Buffer.new("", false)
	for i in 0..5 { buf.lines << "This is line ${i} in the document" }
	buf_view := BufferView.new(&buf)

	x := 0
	y := 0
	width := 100
	height := 3
	min_x := 0
	from_line_num := 0

	buf_view.draw_2(mut mock_ctx, x, y, width, height, from_line_num, min_x, 0)

	assert drawn_rect == [
		DrawnRect{ x: 3, y: 1, width: 98, height: 1 }
	]

	assert drawn_text.len == 42
	assert set_fg_color.len == 42

	// TODO(tauraamui) [14/04/2025]: need to assert against style draws as well
	line_one_expected_drawn_data := [
		DrawnText{ x: 1, y: 1, data: "1" }, DrawnText{ x: 4, y: 1, data: "This" },
		DrawnText{ x: 8, y: 1, data: " " }, DrawnText{ x: 9, y: 1, data: "is" },
		DrawnText{ x: 11, y: 1, data: " " }, DrawnText{ x: 12, y: 1, data: "line" },
		DrawnText{ x: 16, y: 1, data: " " }, DrawnText{ x: 17, y: 1, data: "0" },
		DrawnText{ x: 18, y: 1, data: " " }, DrawnText{ x: 19, y: 1, data: "in" },
		DrawnText{ x: 21, y: 1, data: " " }, DrawnText{ x: 22, y: 1, data: "the" },
		DrawnText{ x: 25, y: 1, data: " " }, DrawnText{ x: 26, y: 1, data: "document" },
	]
	assert drawn_text[..14] == line_one_expected_drawn_data

	line_two_expected_drawn_data := [
		DrawnText{ x: 1, y: 2, data: "2" }, DrawnText{ x: 4, y: 2, data: "This" },
		DrawnText{ x: 8, y: 2, data: " " }, DrawnText{ x: 9, y: 2, data: "is" },
		DrawnText{ x: 11, y: 2, data: " " }, DrawnText{ x: 12, y: 2, data: "line" },
		DrawnText{ x: 16, y: 2, data: " " }, DrawnText{ x: 17, y: 2, data: "1" },
		DrawnText{ x: 18, y: 2, data: " " }, DrawnText{ x: 19, y: 2, data: "in" },
		DrawnText{ x: 21, y: 2, data: " " }, DrawnText{ x: 22, y: 2, data: "the" },
		DrawnText{ x: 25, y: 2, data: " " }, DrawnText{ x: 26, y: 2, data: "document" },
	]
	assert drawn_text[14..28] == line_two_expected_drawn_data

	line_three_expected_drawn_data := [
		DrawnText{ x: 1, y: 3, data: "3" }, DrawnText{ x: 4, y: 3, data: "This" },
		DrawnText{ x: 8, y: 3, data: " " }, DrawnText{ x: 9, y: 3, data: "is" },
		DrawnText{ x: 11, y: 3, data: " " }, DrawnText{ x: 12, y: 3, data: "line" },
		DrawnText{ x: 16, y: 3, data: " " }, DrawnText{ x: 17, y: 3, data: "2" },
		DrawnText{ x: 18, y: 3, data: " " }, DrawnText{ x: 19, y: 3, data: "in" },
		DrawnText{ x: 21, y: 3, data: " " }, DrawnText{ x: 22, y: 3, data: "the" },
		DrawnText{ x: 25, y: 3, data: " " }, DrawnText{ x: 26, y: 3, data: "document" },
	]
	assert drawn_text[28..42] == line_three_expected_drawn_data
}

fn test_buffer_view_draws_lines_10_to_max_height() {
	mut drawn_text := []DrawnText{}
	mut ref := &drawn_text
	mut mock_ctx := MockContextable{
		on_draw_cb: fn [mut ref] (x int, y int, text string) {
			ref << DrawnText{ x: x, y: y, data: text }
		}
	}
	mut buf      := buffer.Buffer.new("", false)
	for i in 0..20 { buf.lines << "${i} This is line ${i} in the document" }
	buf_view := BufferView.new(&buf)

	x := 0
	y := 0
	width := 100
	height := 10
	min_x := 0
	from_line_num := 10

	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num, min_x, 0)

	assert drawn_text == [
		DrawnText{ x: 1, y: 1, data:  "11" },
		DrawnText{ x: 4, y: 1, data:  "10 This is line 10 in the document" },
		DrawnText{ x: 1, y: 2, data:  "12" },
		DrawnText{ x: 4, y: 2, data:  "11 This is line 11 in the document" },
		DrawnText{ x: 1, y: 3, data:  "13" },
		DrawnText{ x: 4, y: 3, data:  "12 This is line 12 in the document" },
		DrawnText{ x: 1, y: 4, data:  "14" },
		DrawnText{ x: 4, y: 4, data:  "13 This is line 13 in the document" },
		DrawnText{ x: 1, y: 5, data:  "15" },
		DrawnText{ x: 4, y: 5, data:  "14 This is line 14 in the document" },
		DrawnText{ x: 1, y: 6, data:  "16" },
		DrawnText{ x: 4, y: 6, data:  "15 This is line 15 in the document" },
		DrawnText{ x: 1, y: 7, data:  "17" },
		DrawnText{ x: 4, y: 7, data:  "16 This is line 16 in the document" },
		DrawnText{ x: 1, y: 8, data:  "18" },
		DrawnText{ x: 4, y: 8, data:  "17 This is line 17 in the document" },
		DrawnText{ x: 1, y: 9, data:  "19" },
		DrawnText{ x: 4, y: 9, data:  "18 This is line 18 in the document" },
		DrawnText{ x: 1, y: 10, data: "20" },
		DrawnText{ x: 4, y: 10, data: "19 This is line 19 in the document" }
	]
}

fn test_buffer_view_draws_lines_10_to_max_height_2() {
	mut drawn_text := []DrawnText{}
	mut drawn_text_ref := &drawn_text

	mut set_fg_color := []draw.Color{}
	mut set_fg_color_ref := &set_fg_color

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
			set_fg_color_ref << c
		}
	}

	mut buf := buffer.Buffer.new("", false)
	for i in 0..20 { buf.lines << "This is line ${i} in the document" }
	buf_view := BufferView.new(&buf)

	x := 0
	y := 0
	width := 100
	height := 10
	min_x := 0
	from_line_num := 10

	buf_view.draw_2(mut mock_ctx, x, y, width, height, from_line_num, min_x, 12)

	// TODO(tauraamui) [14/04/2025]: need to assert against style draws as well
	assert drawn_rect == [
		DrawnRect{ x: 4, y: 3, width: 97, height: 1 }
	]

	assert drawn_text.len == 140
	assert set_fg_color.len == 140

	line_one_expected_drawn_data := [
		DrawnText{ x: 1, y: 1, data: "11" }, DrawnText{ x: 5, y: 1, data: "This" },
		DrawnText{ x: 9, y: 1, data: " " }, DrawnText{ x: 10, y: 1, data: "is" },
		DrawnText{ x: 12, y: 1, data: " " }, DrawnText{ x: 13, y: 1, data: "line" },
		DrawnText{ x: 17, y: 1, data: " " }, DrawnText{ x: 18, y: 1, data: "10" },
		DrawnText{ x: 20, y: 1, data: " " }, DrawnText{ x: 21, y: 1, data: "in" },
		DrawnText{ x: 23, y: 1, data: " " }, DrawnText{ x: 24, y: 1, data: "the" },
		DrawnText{ x: 27, y: 1, data: " " }, DrawnText{ x: 28, y: 1, data: "document" },
	]
	assert drawn_text[..14] == line_one_expected_drawn_data

	line_two_expected_drawn_data := [
		DrawnText{ x: 1, y: 2, data: "12" }, DrawnText{ x: 5, y: 2, data: "This" },
		DrawnText{ x: 9, y: 2, data: " " }, DrawnText{ x: 10, y: 2, data: "is" },
		DrawnText{ x: 12, y: 2, data: " " }, DrawnText{ x: 13, y: 2, data: "line" },
		DrawnText{ x: 17, y: 2, data: " " }, DrawnText{ x: 18, y: 2, data: "11" },
		DrawnText{ x: 20, y: 2, data: " " }, DrawnText{ x: 21, y: 2, data: "in" },
		DrawnText{ x: 23, y: 2, data: " " }, DrawnText{ x: 24, y: 2, data: "the" },
		DrawnText{ x: 27, y: 2, data: " " }, DrawnText{ x: 28, y: 2, data: "document" },
	]
	assert drawn_text[14..28] == line_two_expected_drawn_data

	line_three_expected_drawn_data := [
		DrawnText{ x: 1, y: 3, data: "13" }, DrawnText{ x: 5, y: 3, data: "This" },
		DrawnText{ x: 9, y: 3, data: " " }, DrawnText{ x: 10, y: 3, data: "is" },
		DrawnText{ x: 12, y: 3, data: " " }, DrawnText{ x: 13, y: 3, data: "line" },
		DrawnText{ x: 17, y: 3, data: " " }, DrawnText{ x: 18, y: 3, data: "12" },
		DrawnText{ x: 20, y: 3, data: " " }, DrawnText{ x: 21, y: 3, data: "in" },
		DrawnText{ x: 23, y: 3, data: " " }, DrawnText{ x: 24, y: 3, data: "the" },
		DrawnText{ x: 27, y: 3, data: " " }, DrawnText{ x: 28, y: 3, data: "document" },
	]
	assert drawn_text[28..42] == line_three_expected_drawn_data
}

fn test_buffer_view_draws_lines_0_to_max_height_min_x_is_6() {
	mut drawn_text := []DrawnText{}
	mut ref := &drawn_text
	mut mock_ctx := MockContextable{
		on_draw_cb: fn [mut ref] (x int, y int, text string) {
			ref << DrawnText{ x: x, y: y, data: text }
		}
	}
	mut buf      := buffer.Buffer.new("", false)
	for i in 0..20 { buf.lines << "${i} This is line ${i} in the document" }
	mut buf_view := BufferView.new(&buf)

	x := 0
	y := 0
	width := 100
	height := 10
	min_x := 6
	from_line_num := 0

	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num, min_x, 0)

	assert drawn_text == [
		DrawnText{ x: 2, y: 1, data: "1" }
		DrawnText{ x: 4, y: 1, data:  " is line 0 in the document" },
		DrawnText{ x: 2, y: 2, data: "2" }
		DrawnText{ x: 4, y: 2, data:  " is line 1 in the document" },
		DrawnText{ x: 2, y: 3, data: "3" }
		DrawnText{ x: 4, y: 3, data:  " is line 2 in the document" },
		DrawnText{ x: 2, y: 4, data: "4" }
		DrawnText{ x: 4, y: 4, data:  " is line 3 in the document" },
		DrawnText{ x: 2, y: 5, data: "5" }
		DrawnText{ x: 4, y: 5, data:  " is line 4 in the document" },
		DrawnText{ x: 2, y: 6, data: "6" }
		DrawnText{ x: 4, y: 6, data:  " is line 5 in the document" },
		DrawnText{ x: 2, y: 7, data: "7" }
		DrawnText{ x: 4, y: 7, data:  " is line 6 in the document" },
		DrawnText{ x: 2, y: 8, data: "8" }
		DrawnText{ x: 4, y: 8, data:  " is line 7 in the document" },
		DrawnText{ x: 2, y: 9, data: "9" }
		DrawnText{ x: 4, y: 9, data:  " is line 8 in the document" },
		DrawnText{ x: 1, y: 10, data: "10" }
		DrawnText{ x: 4, y: 10, data: " is line 9 in the document" }
	]
}

fn test_buffer_view_draws_lines_0_to_max_height_min_x_0_max_width_12() {
	mut drawn_text := []DrawnText{}
	mut ref := &drawn_text
	mut mock_ctx := MockContextable{
		on_draw_cb: fn [mut ref] (x int, y int, text string) {
			ref << DrawnText{ x: x, y: y, data: text }
		}
	}
	mut buf      := buffer.Buffer.new("", false)
	for i in 0..20 { buf.lines << "${i} This is line ${i} in the document" }
	mut buf_view := BufferView.new(&buf)

	x := 0
	y := 0
	width := 12
	height := 10
	min_x := 0
	from_line_num := 0

	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num, min_x, 0)

	assert drawn_text == [
		DrawnText{ x: 2, y: 1, data: "1" }
		DrawnText{ x: 4, y: 1, data:  "0 This i" },
		DrawnText{ x: 2, y: 2, data: "2" }
		DrawnText{ x: 4, y: 2, data:  "1 This i" },
		DrawnText{ x: 2, y: 3, data: "3" }
		DrawnText{ x: 4, y: 3, data:  "2 This i" },
		DrawnText{ x: 2, y: 4, data: "4" }
		DrawnText{ x: 4, y: 4, data:  "3 This i" },
		DrawnText{ x: 2, y: 5, data: "5" }
		DrawnText{ x: 4, y: 5, data:  "4 This i" },
		DrawnText{ x: 2, y: 6, data: "6" }
		DrawnText{ x: 4, y: 6, data:  "5 This i" },
		DrawnText{ x: 2, y: 7, data: "7" }
		DrawnText{ x: 4, y: 7, data:  "6 This i" },
		DrawnText{ x: 2, y: 8, data: "8" }
		DrawnText{ x: 4, y: 8, data:  "7 This i" },
		DrawnText{ x: 2, y: 9, data: "9" }
		DrawnText{ x: 4, y: 9, data:  "8 This i" },
		DrawnText{ x: 1, y: 10, data: "10" }
		DrawnText{ x: 4, y: 10, data: "9 This i" }
	]
}

struct MockContextable {
mut:
	on_draw_cb         fn (x int, y int, text string)
	on_draw_rect_cb    fn (x int, y int, width int, height int)
	on_set_fg_color_cb fn (c draw.Color)
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

fn (mockctx MockContextable) set_bg_color(c draw.Color) {}

fn (mockctx MockContextable) revert_bg_color() {}

fn (mockctx MockContextable) reset_color() {}

fn (mockctx MockContextable) reset_bg_color() {}

fn (mockctx MockContextable) bold() {}

fn (mockctx MockContextable) reset() {}

fn (mockctx MockContextable) run() ! {}

fn (mockctx MockContextable) clear() {}

fn (mockctx MockContextable) flush() {}
