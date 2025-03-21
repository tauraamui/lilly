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

pub struct BufferView {
	buf   &buffer.Buffer = unsafe { nil }
mut:
	min_x int
}

pub fn BufferView.new(buf &buffer.Buffer) BufferView {
	return BufferView{ buf: buf }
}

pub fn (buf_view BufferView) draw(
	mut ctx draw.Contextable,
	x int, y int,
	width int, height int,
	from_line_num int,
	cursor_y_pos int
) {
	if buf_view.buf == unsafe { nil } { return }

	mut screenspace_x_offset := 1 + buf_view.buf.num_of_lines().str().runes().len
	mut screenspace_y_offset := 1
	for document_line_num, line in buf_view.buf.line_iterator() {
		// if we haven't reached the line to render in the document yet, skip this
		if document_line_num < from_line_num { continue }

		// draw line number
		draw_line_number(mut ctx, x + screenspace_x_offset, y + screenspace_y_offset, document_line_num)

		// draw the line of text, offset by the position of the buffer view
		draw_text_line(mut ctx, x + screenspace_x_offset + 1, y + screenspace_y_offset, line, buf_view.min_x, width)

		screenspace_y_offset += 1
		// detect if number of lines drawn would exceed current height of view
		if screenspace_y_offset > height { return }
	}
}

const line_num_fg_color = draw.Color{ r: 117, g: 118, b: 120 }

fn draw_line_number(mut ctx draw.Contextable, x int, y int, line_num int) {
	defer { ctx.reset_color() }
	ctx.set_color(line_num_fg_color)

	mut line_num_str := "${line_num + 1}"
	ctx.draw_text(x - line_num_str.runes().len, y, line_num_str)
}

fn draw_text_line(mut ctx draw.Contextable, x int, y int, line string, min_x int, width int) {
	if min_x >= line.runes().len { ctx.draw_text(x, y, ""); return }

	mut line_past_min_x := line.runes()[min_x..].string()
	if line_past_min_x.len > (width - x) {
		line_past_min_x = line_past_min_x[..(width - x)]
	}

	ctx.draw_text(x, y, line_past_min_x)
}

