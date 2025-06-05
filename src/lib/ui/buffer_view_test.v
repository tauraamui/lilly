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
import lib.utf8

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
	mut buf_view := BufferView.new(&buf, [], 0)

	x := 0
	y := 0
	width := 100
	height := 3
	min_x := 0
	from_line_num := 0

	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num, min_x, 0, false, .normal)

	assert drawn_rect == [
		DrawnRect{ x: 2, y: 0, width: 99, height: 1 }
	]

	assert drawn_text.len == 56
	assert set_fg_color.len == 56

	// TODO(tauraamui) [14/04/2025]: need to assert against style draws as well
	line_one_expected_drawn_data := [
		DrawnText{ x: 0, y: 0, data: "1" }, DrawnText{ x: 2, y: 0, data: "This" },
		DrawnText{ x: 6, y: 0, data: " " }, DrawnText{ x: 7, y: 0, data: "is" },
		DrawnText{ x: 9, y: 0, data: " " }, DrawnText{ x: 10, y: 0, data: "line" },
		DrawnText{ x: 14, y: 0, data: " " }, DrawnText{ x: 15, y: 0, data: "0" },
		DrawnText{ x: 16, y: 0, data: " " }, DrawnText{ x: 17, y: 0, data: "in" },
		DrawnText{ x: 19, y: 0, data: " " }, DrawnText{ x: 20, y: 0, data: "the" },
		DrawnText{ x: 23, y: 0, data: " " }, DrawnText{ x: 24, y: 0, data: "document" },
	]
	assert drawn_text[..14] == line_one_expected_drawn_data

	line_two_expected_drawn_data := [
		DrawnText{ x: 0, y: 1, data: "2" }, DrawnText{ x: 2, y: 1, data: "This" },
		DrawnText{ x: 6, y: 1, data: " " }, DrawnText{ x: 7, y: 1, data: "is" },
		DrawnText{ x: 9, y: 1, data: " " }, DrawnText{ x: 10, y: 1, data: "line" },
		DrawnText{ x: 14, y: 1, data: " " }, DrawnText{ x: 15, y: 1, data: "1" },
		DrawnText{ x: 16, y: 1, data: " " }, DrawnText{ x: 17, y: 1, data: "in" },
		DrawnText{ x: 19, y: 1, data: " " }, DrawnText{ x: 20, y: 1, data: "the" },
		DrawnText{ x: 23, y: 1, data: " " }, DrawnText{ x: 24, y: 1, data: "document" },
	]
	assert drawn_text[14..28] == line_two_expected_drawn_data

	line_three_expected_drawn_data := [
		DrawnText{ x: 0, y: 2, data: "3" }, DrawnText{ x: 2, y: 2, data: "This" },
		DrawnText{ x: 6, y: 2, data: " " }, DrawnText{ x: 7, y: 2, data: "is" },
		DrawnText{ x: 9, y: 2, data: " " }, DrawnText{ x: 10, y: 2, data: "line" },
		DrawnText{ x: 14, y: 2, data: " " }, DrawnText{ x: 15, y: 2, data: "2" },
		DrawnText{ x: 16, y: 2, data: " " }, DrawnText{ x: 17, y: 2, data: "in" },
		DrawnText{ x: 19, y: 2, data: " " }, DrawnText{ x: 20, y: 2, data: "the" },
		DrawnText{ x: 23, y: 2, data: " " }, DrawnText{ x: 24, y: 2, data: "document" },
	]
	assert drawn_text[28..42] == line_three_expected_drawn_data
}

fn test_buffer_view_draws_1_line_as_single_segment_that_that_elapses_max_width() {
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
	buf.lines << "Thisisthelineinthedocument"
	mut buf_view := BufferView.new(&buf, [], 0)

	x := 0
	y := 0
	width := 20
	height := 10
	min_x := 0
	from_line_num := 0

	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num, min_x, 0, false, .normal)

	// TODO(tauraamui) [14/04/2025]: need to assert against style draws as well
	assert drawn_rect == [
		DrawnRect{ x: 2, y: 0, width: 19, height: 1 }
	]

	assert drawn_text.len == 2
	assert set_fg_color.len == 2

	line_one_expected_drawn_data := [
		DrawnText{ x: 0, y: 0, data: "1" }, DrawnText{ x: 2, y: 0, data: "Thisisthelineinthe" },
	]
	assert drawn_text[..2] == line_one_expected_drawn_data
}

fn test_buffer_view_draws_1_line_as_multiple_segments_highlighted_as_expected() {
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
	buf.lines << "fn name_of_function()"
	mut buf_view := BufferView.new(&buf, [], 0)

	x := 0
	y := 0
	width := 40
	height := 10
	min_x := 0
	from_line_num := 0

	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num, min_x, 0, false, .normal)

	// TODO(tauraamui) [14/04/2025]: need to assert against style draws as well
	assert drawn_rect == [
		DrawnRect{ x: 2, y: 0, width: 39, height: 1 }
	]

	assert drawn_text.len == 9
	assert set_fg_color.len == 9

	line_one_expected_drawn_data := [
		DrawnText{ x: 0, y: 0, data: "1" }, DrawnText{ x: 2, y: 0, data: "fn" },
		DrawnText{ x: 4, y: 0, data: " " }, DrawnText{ x: 5, y: 0, data: "name_of_function" },
		DrawnText{ x: 20, y: 0, data: "(" }, DrawnText{ x: 21, y: 0, data: ")" },
	]

	// SKIP FOR NOW
	// assert drawn_text == line_one_expected_drawn_data
}

fn test_buffer_view_draws_1_line_as_single_segment_single_emoji() {
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
	buf.lines << utf8.emoji_shark_char
	mut buf_view := BufferView.new(&buf, [], 0)

	x := 0
	y := 0
	width := 20
	height := 10
	min_x := 0
	from_line_num := 0

	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num, min_x, 0, false, .normal)

	// TODO(tauraamui) [14/04/2025]: need to assert against style draws as well
	assert drawn_rect == [
		DrawnRect{ x: 2, y: 0, width: 19, height: 1 }
	]

	assert drawn_text.len == 2
	assert set_fg_color.len == 2

	line_one_expected_drawn_data := [
		DrawnText{ x: 0, y: 0, data: "1" }, DrawnText{ x: 2, y: 0, data: "${utf8.emoji_shark_char}" },
	]
	assert drawn_text[..2] == line_one_expected_drawn_data
}


fn test_buffer_view_draws_lines_10_to_max_height() {
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
	mut buf_view := BufferView.new(&buf, [], 0)

	x := 0
	y := 0
	width := 100
	height := 10
	min_x := 0
	from_line_num := 10

	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num, min_x, 12, false, .normal)

	// TODO(tauraamui) [14/04/2025]: need to assert against style draws as well
	assert drawn_rect == [
		DrawnRect{ x: 3, y: 2, width: 98, height: 1 }
	]

	assert drawn_text.len == 140
	assert set_fg_color.len == 140

	line_one_expected_drawn_data := [
		DrawnText{ x: 0, y: 0, data: "11" }, DrawnText{ x: 3, y: 0, data: "This" },
		DrawnText{ x: 7, y: 0, data: " " }, DrawnText{ x: 8, y: 0, data: "is" },
		DrawnText{ x: 10, y: 0, data: " " }, DrawnText{ x: 11, y: 0, data: "line" },
		DrawnText{ x: 15, y: 0, data: " " }, DrawnText{ x: 16, y: 0, data: "10" },
		DrawnText{ x: 18, y: 0, data: " " }, DrawnText{ x: 19, y: 0, data: "in" },
		DrawnText{ x: 21, y: 0, data: " " }, DrawnText{ x: 22, y: 0, data: "the" },
		DrawnText{ x: 25, y: 0, data: " " }, DrawnText{ x: 26, y: 0, data: "document" },
	]
	assert drawn_text[..14] == line_one_expected_drawn_data

	line_two_expected_drawn_data := [
		DrawnText{ x: 0, y: 1, data: "12" }, DrawnText{ x: 3, y: 1, data: "This" },
		DrawnText{ x: 7, y: 1, data: " " }, DrawnText{ x: 8, y: 1, data: "is" },
		DrawnText{ x: 10, y: 1, data: " " }, DrawnText{ x: 11, y: 1, data: "line" },
		DrawnText{ x: 15, y: 1, data: " " }, DrawnText{ x: 16, y: 1, data: "11" },
		DrawnText{ x: 18, y: 1, data: " " }, DrawnText{ x: 19, y: 1, data: "in" },
		DrawnText{ x: 21, y: 1, data: " " }, DrawnText{ x: 22, y: 1, data: "the" },
		DrawnText{ x: 25, y: 1, data: " " }, DrawnText{ x: 26, y: 1, data: "document" },
	]
	assert drawn_text[14..28] == line_two_expected_drawn_data

	line_three_expected_drawn_data := [
		DrawnText{ x: 0, y: 2, data: "13" }, DrawnText{ x: 3, y: 2, data: "This" },
		DrawnText{ x: 7, y: 2, data: " " }, DrawnText{ x: 8, y: 2, data: "is" },
		DrawnText{ x: 10, y: 2, data: " " }, DrawnText{ x: 11, y: 2, data: "line" },
		DrawnText{ x: 15, y: 2, data: " " }, DrawnText{ x: 16, y: 2, data: "12" },
		DrawnText{ x: 18, y: 2, data: " " }, DrawnText{ x: 19, y: 2, data: "in" },
		DrawnText{ x: 21, y: 2, data: " " }, DrawnText{ x: 22, y: 2, data: "the" },
		DrawnText{ x: 25, y: 2, data: " " }, DrawnText{ x: 26, y: 2, data: "document" },
	]
	assert drawn_text[28..42] == line_three_expected_drawn_data

	line_four_expected_drawn_data := [
		DrawnText{ x: 0, y: 3, data: "14" }, DrawnText{ x: 3, y: 3, data: "This" },
		DrawnText{ x: 7, y: 3, data: " " }, DrawnText{ x: 8, y: 3, data: "is" },
		DrawnText{ x: 10, y: 3, data: " " }, DrawnText{ x: 11, y: 3, data: "line" },
		DrawnText{ x: 15, y: 3, data: " " }, DrawnText{ x: 16, y: 3, data: "13" },
		DrawnText{ x: 18, y: 3, data: " " }, DrawnText{ x: 19, y: 3, data: "in" },
		DrawnText{ x: 21, y: 3, data: " " }, DrawnText{ x: 22, y: 3, data: "the" },
		DrawnText{ x: 25, y: 3, data: " " }, DrawnText{ x: 26, y: 3, data: "document" },
	]
	assert drawn_text[42..56] == line_four_expected_drawn_data

	line_five_expected_drawn_data := [
		DrawnText{ x: 0, y: 4, data: "15" }, DrawnText{ x: 3, y: 4, data: "This" },
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
		DrawnText{ x: 0, y: 6, data: "17" }, DrawnText{ x: 3, y: 6, data: "This" },
		DrawnText{ x: 7, y: 6, data: " " }, DrawnText{ x: 8, y: 6, data: "is" },
		DrawnText{ x: 10, y: 6, data: " " }, DrawnText{ x: 11, y: 6, data: "line" },
		DrawnText{ x: 15, y: 6, data: " " }, DrawnText{ x: 16, y: 6, data: "16" },
		DrawnText{ x: 18, y: 6, data: " " }, DrawnText{ x: 19, y: 6, data: "in" },
		DrawnText{ x: 21, y: 6, data: " " }, DrawnText{ x: 22, y: 6, data: "the" },
		DrawnText{ x: 25, y: 6, data: " " }, DrawnText{ x: 26, y: 6, data: "document" },
	]
	assert drawn_text[84..98] == line_seven_expected_drawn_data

	line_eight_expected_drawn_data := [
		DrawnText{ x: 0, y: 7, data: "18" }, DrawnText{ x: 3, y: 7, data: "This" },
		DrawnText{ x: 7, y: 7, data: " " }, DrawnText{ x: 8, y: 7, data: "is" },
		DrawnText{ x: 10, y: 7, data: " " }, DrawnText{ x: 11, y: 7, data: "line" },
		DrawnText{ x: 15, y: 7, data: " " }, DrawnText{ x: 16, y: 7, data: "17" },
		DrawnText{ x: 18, y: 7, data: " " }, DrawnText{ x: 19, y: 7, data: "in" },
		DrawnText{ x: 21, y: 7, data: " " }, DrawnText{ x: 22, y: 7, data: "the" },
		DrawnText{ x: 25, y: 7, data: " " }, DrawnText{ x: 26, y: 7, data: "document" },
	]
	assert drawn_text[98..112] == line_eight_expected_drawn_data

	line_nine_expected_drawn_data := [
		DrawnText{ x: 0, y: 8, data: "19" }, DrawnText{ x: 3, y: 8, data: "This" },
		DrawnText{ x: 7, y: 8, data: " " }, DrawnText{ x: 8, y: 8, data: "is" },
		DrawnText{ x: 10, y: 8, data: " " }, DrawnText{ x: 11, y: 8, data: "line" },
		DrawnText{ x: 15, y: 8, data: " " }, DrawnText{ x: 16, y: 8, data: "18" },
		DrawnText{ x: 18, y: 8, data: " " }, DrawnText{ x: 19, y: 8, data: "in" },
		DrawnText{ x: 21, y: 8, data: " " }, DrawnText{ x: 22, y: 8, data: "the" },
		DrawnText{ x: 25, y: 8, data: " " }, DrawnText{ x: 26, y: 8, data: "document" },
	]
	assert drawn_text[112..126] == line_nine_expected_drawn_data

	line_ten_expected_drawn_data := [
		DrawnText{ x: 0, y: 9, data: "20" }, DrawnText{ x: 3, y: 9, data: "This" },
		DrawnText{ x: 7, y: 9, data: " " }, DrawnText{ x: 8, y: 9, data: "is" },
		DrawnText{ x: 10, y: 9, data: " " }, DrawnText{ x: 11, y: 9, data: "line" },
		DrawnText{ x: 15, y: 9, data: " " }, DrawnText{ x: 16, y: 9, data: "19" },
		DrawnText{ x: 18, y: 9, data: " " }, DrawnText{ x: 19, y: 9, data: "in" },
		DrawnText{ x: 21, y: 9, data: " " }, DrawnText{ x: 22, y: 9, data: "the" },
		DrawnText{ x: 25, y: 9, data: " " }, DrawnText{ x: 26, y: 9, data: "document" },
	]
	assert drawn_text[126..140] == line_ten_expected_drawn_data
}

fn test_buffer_view_draws_lines_10_to_max_height_relative_line_numbers_enabled() {
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
	mut buf_view := BufferView.new(&buf, [], 0)

	x := 0
	y := 0
	width := 100
	height := 10
	min_x := 0
	from_line_num := 10

	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num, min_x, 15, true, .normal) // toggle relative line numbers on

	// TODO(tauraamui) [14/04/2025]: need to assert against style draws as well
	assert drawn_rect == [
		DrawnRect{ x: 3, y: 5, width: 98, height: 1 }
	]

	assert drawn_text.len == 140
	assert set_fg_color.len == 140

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
	mut buf_view := BufferView.new(&buf, [], 0)

	x := 0
	y := 0
	width := 100
	height := 10
	min_x := 0
	from_line_num := 10

	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num, min_x, 15, true, .normal) // toggle relative line numbers on

	// TODO(tauraamui) [14/04/2025]: need to assert against style draws as well
	assert drawn_rect == [
		DrawnRect{ x: 3, y: 5, width: 98, height: 1 }
	]

	assert drawn_text.len == 140
	assert set_fg_color.len == 140

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
	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num, min_x, 13, true, .normal) // toggle relative line numbers on

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
	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num, min_x, 18, true, .normal) // toggle relative line numbers on

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

	mut buf      := buffer.Buffer.new("", false)
	for i in 0..3 { buf.lines << "${i} This is line ${i} in the document" }
	mut buf_view := BufferView.new(&buf, [], 0)

	x := 0
	y := 0
	width := 14
	height := 4
	min_x := 0
	from_line_num := 0

	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num, min_x, 0, false, .normal)

	// TODO(tauraamui) [14/04/2025]: need to assert against style draws as well
	assert drawn_rect == [
		DrawnRect{ x: 2, y: 0, width: 13, height: 1 }
	]

	assert drawn_text.len == 24
	assert set_fg_color.len == 24

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

	mut buf      := buffer.Buffer.new("", false)
	for i in 0..3 { buf.lines << "${i} This is line ${i} in the document" }
	mut buf_view := BufferView.new(&buf, [], 0)

	x := 0
	y := 0
	width := 56
	height := 4
	min_x := 4
	from_line_num := 0

	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num, min_x, 0, false, .normal)

	// TODO(tauraamui) [14/04/2025]: need to assert against style draws as well
	assert drawn_rect == [
		DrawnRect{ x: 2, y: 0, width: 55, height: 1 }
	]

	assert drawn_text.len == 42
	assert set_fg_color.len == 42

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

	mut buf      := buffer.Buffer.new("", false)
	for i in 0..3 { buf.lines << "${i} This is line ${i} in the document" }
	mut buf_view := BufferView.new(&buf, [], 0)

	x := 0
	y := 0
	width := 56
	height := 4
	min_x := 21
	from_line_num := 0

	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num, min_x, 0, false, .normal)

	// TODO(tauraamui) [14/04/2025]: need to assert against style draws as well
	assert drawn_rect == [
		DrawnRect{ x: 2, y: 0, width: 55, height: 1 }
	]

	assert drawn_text.len == 12
	assert set_fg_color.len == 12

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

	mut buf      := buffer.Buffer.new("", false)
	for i in 0..3 { buf.lines << "${i} This is line ${i} in the document" }
	mut buf_view := BufferView.new(&buf, [], 0)

	x := 0
	y := 0
	width := 12
	height := 4
	min_x := 21
	from_line_num := 0

	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num, min_x, 0, false, .normal)

	// TODO(tauraamui) [14/04/2025]: need to assert against style draws as well
	assert drawn_rect == [
		DrawnRect{ x: 2, y: 0, width: 11, height: 1 }
	]

	assert drawn_text.len == 12
	assert set_fg_color.len == 12

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

fn (mockctx MockContextable) set_bg_color(c draw.Color) {}

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
