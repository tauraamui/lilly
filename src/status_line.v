// Copyright 2023 The Lilly Editor contributors
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

module main

import term.ui as tui

struct Status {
	mode      Mode
	cursor_x  int
	cursor_y  int
	file_name string
}

fn draw_status_line(mut ctx tui.Context, status Status) {
	defer { ctx.reset() }

	y := ctx.window_height - 1
	// draw base dark rectangle for the status line
	ctx.set_bg_color(r: 25, g: 25, b: 25)
	ctx.draw_rect(12, y, ctx.window_width, y)

	// invoke the mode indicator draw
	mut offset := status.mode.draw(mut ctx, 1, y) + 2

	// if filename provided, render its segment next
	if status.file_name.len > 0 { offset += draw_file_name_segment(mut ctx, offset, y, status.file_name) }
	paint_shape_text(mut ctx, 1 + offset, y, Color{ 25, 25, 25 }, "${slant_left_flat_top}")

	// render the cursor status as a right trailing segment
	cursor_info_label := "${status.cursor_y+1}:${status.cursor_x+1}"
	paint_shape_text(mut ctx, ctx.window_width - 1, y, Color { 245, 42, 42 }, "${block}${block}")
	ctx.bold()
	paint_text_on_background(mut ctx, ctx.window_width - 1 - cursor_info_label.len, y, Color{ 245, 42, 42 }, Color{ 255, 255, 255 }, cursor_info_label)
	paint_shape_text(mut ctx, ctx.window_width - 1 - cursor_info_label.len - 2, y, Color { 245, 42, 42 }, "${slant_left_flat_bottom}${block}")
}

fn draw_file_name_segment(mut ctx tui.Context, x int, y int, file_name string) int {
	paint_shape_text(mut ctx, x, y, Color{ 86, 86, 86 }, "${slant_left_flat_top}${block}")
	mut offset := 2
	ctx.bold()
	paint_text_on_background(mut ctx, x + offset, y, Color{ 86, 86, 86 }, Color{ 230, 230, 230 }, file_name)
	offset += file_name.len
	paint_shape_text(mut ctx, x + offset, y, Color{ 86, 86, 86 }, "${block}${slant_right_flat_bottom}")
	offset += 1
	return offset
}
