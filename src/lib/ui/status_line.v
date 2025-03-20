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

module ui

import lib.draw
import lib.core

pub struct SearchSelection {
pub:
	active  bool
	total   int
	current int
}

pub struct Status {
pub:
	mode       core.Mode
	cursor_x   int
	cursor_y   int
	file_name  string
	selection  SearchSelection
	git_branch string
	dirty      bool
}

pub fn draw_status_line(mut ctx draw.Contextable, status Status) {
	defer { ctx.reset() }

	y := ctx.window_height() - 1
	// draw base dark rectangle for the status line
	// ctx.set_bg_color(r: 25, g: 25, b: 25)
	// FIX(tauraamui) [20/03/2025]: this has been incorrectly seemingly rendering
	//                              a full rectangle over the entire viewport this whole
	//                              time, no wonder we are/were seeing pretty consistent flickering
	//                              on most terminal emulators
	//
	//                              for now the preference here is to just stop rendering that segment
	// ctx.draw_rect(12, y, ctx.window_width(), 1)

	// invoke the mode indicator draw
	mut offset := status.mode.draw(mut ctx, 1, y)

	// if filename provided, render its segment next
	if status.file_name.len > 0 {
        dirty_indicator := if status.dirty { ' [+]' } else { '' }
        offset += draw_file_name_segment(mut ctx, offset, y, status.file_name + dirty_indicator)
	}

	// if search selection active/provided, render it's segment next
	if status.selection.active {
		offset += draw_search_selection_info_segment(mut ctx, offset, y, status.selection)
	}

	// if git branch active/provided, render it's segment next
	if status.git_branch.len > 0 {
		offset += draw_git_branch_section(mut ctx, offset, y, status.git_branch)
	}

	// draw leaning end of base status line bar
	draw.paint_shape_text(mut ctx, offset, y, draw.Color{25, 25, 25}, '${core.slant_left_flat_top}')
	offset += 1

	// render the cursor status as a right trailing segment
	draw_cursor_position_segment(mut ctx, 1, y, offset, status.cursor_x, status.cursor_y)
}

fn draw_file_name_segment(mut ctx draw.Contextable, x int, y int, file_name string) int {
	draw.paint_shape_text(mut ctx, x, y, draw.Color{86, 86, 86}, '${core.slant_left_flat_top}${core.block}')
	mut offset := 2
	ctx.bold()
	draw.paint_text_on_background(mut ctx, x + offset, y, draw.Color{86, 86, 86}, draw.Color{230, 230, 230},
		file_name)
	offset += file_name.len
	draw.paint_shape_text(mut ctx, x + offset, y, draw.Color{86, 86, 86}, '${core.block}${core.slant_right_flat_bottom}')
	offset += 2
	return offset
}

fn draw_search_selection_info_segment(mut ctx draw.Contextable, x int, y int, selection SearchSelection) int {
	selection_info_label := '${selection.current}/${selection.total}'
	mut offset := 2
	draw.paint_shape_text(mut ctx, x, y, core.status_purple, '${core.slant_left_flat_top}${core.block}')
	draw.paint_text_on_background(mut ctx, x + offset, y, core.status_purple, draw.Color{230, 230, 230},
		selection_info_label)
	offset += selection_info_label.len
	draw.paint_shape_text(mut ctx, x + offset, y, core.status_purple, '${core.block}${core.slant_right_flat_bottom}')
	offset += 2
	return offset
}

fn draw_git_branch_section(mut ctx draw.Contextable, x int, y int, git_branch string) int {
	draw.paint_shape_text(mut ctx, x, y, core.status_dark_lilac, '${core.slant_left_flat_top}${core.block}')
	mut offset := 2
	draw.paint_text_on_background(mut ctx, x + offset, y, core.status_dark_lilac, draw.Color{230, 230, 230},
		git_branch)
	offset += git_branch.runes().len - 1
	draw.paint_shape_text(mut ctx, x + offset, y, draw.Color{154, 119, 209}, '${core.block}${core.slant_right_flat_bottom}')
	offset += 2
	return offset
}

fn draw_cursor_position_segment(mut ctx draw.Contextable, x int, y int, last_segment_offset int, cursor_x int, cursor_y int) int {
	cursor_info_label := '${cursor_y + 1}:${cursor_x + 1}'
	draw.paint_shape_text(mut ctx, ctx.window_width() - 1, y, draw.Color{245, 42, 42}, '${core.block}${core.block}')
	ctx.bold()
	draw.paint_text_on_background(mut ctx, ctx.window_width() - 1 - cursor_info_label.len,
		y, draw.Color{245, 42, 42}, draw.Color{255, 255, 255}, cursor_info_label)
	draw.paint_shape_text(mut ctx, ctx.window_width() - 2 - cursor_info_label.len - 2, y, draw.Color{245, 42, 42},
		'${core.slant_right_flat_top}${core.slant_left_flat_bottom}${core.block}')
	draw.paint_shape_text(mut ctx, ctx.window_width() - 2 - cursor_info_label.len - 2, y, draw.Color{25, 25, 25},
		'${core.slant_right_flat_top}')
	ctx.set_bg_color(draw.Color{25, 25, 25})
	ctx.draw_rect(last_segment_offset, y, (ctx.window_width() - 2 - cursor_info_label.len - 2) - last_segment_offset, 1)
	ctx.reset_bg_color()
	return 0
}
