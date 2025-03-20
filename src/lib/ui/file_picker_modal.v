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

import os
import strings
import lib.draw
import lib.core

const max_height = 20

@[noinit]
pub struct FilePickerModal {
	title          string
pub mut:
	special_mode   bool // NOTE(tsauraamui) [14/02/2025] will likely deprecate or change this for now
mut:
	file_paths     []string
	search         FileSearch
	open           bool
	current_sel_id int
	from           int
}

struct FileSearch {
mut:
	query    string
	cursor_x int
}

fn (mut file_search FileSearch) put_char(c string) {
	first := file_search.query[..file_search.cursor_x]
	last := file_search.query[file_search.cursor_x..]
	file_search.query = '${first}${c}${last}'
	file_search.cursor_x += 1
}

fn (mut file_search FileSearch) backspace() {
	if file_search.cursor_x == 0 {
		return
	}
	first := file_search.query[..file_search.cursor_x - 1]
	last := file_search.query[file_search.cursor_x..]
	file_search.query = '${first}${last}'
	file_search.cursor_x -= 1
	if file_search.cursor_x < 0 {
		file_search.cursor_x = 0
	}
}

pub fn FilePickerModal.new(title string, file_paths []string, special_mode bool) FilePickerModal {
	return FilePickerModal{
		title: if title.len == 0 { "FILE PICKER" } else { title }
		file_paths: file_paths
		special_mode: special_mode
		search: FileSearch{}
	}
}

pub fn (mut f_picker FilePickerModal) open() {
	f_picker.open = true
}

pub fn (mut f_picker FilePickerModal) draw(mut ctx draw.Contextable) {
	defer { ctx.reset_bg_color() }
	ctx.set_color(r: 245, g: 245, b: 245)
	ctx.set_bg_color(r: 15, g: 15, b: 15)
	mut y_offset := 1
	debug_mode_str := if ctx.render_debug() { " *** RENDER DEBUG MODE ***" } else { "" }
	special_mode_str := if f_picker.special_mode { " - SPECIAL MODE" } else { "" }
	ctx.draw_text(1, y_offset, "=== ${debug_mode_str} ${f_picker.title}${special_mode_str} ${debug_mode_str} ===")
	y_offset += 1
	ctx.set_cursor_position(1, y_offset + f_picker.current_sel_id - f_picker.from)
	y_offset += f_picker.draw_scrollable_list(mut ctx, y_offset, f_picker.file_paths)
	ctx.set_bg_color(r: 153, g: 95, b: 146)
	ctx.draw_rect(1, y_offset, ctx.window_width(), 1)
	search_label := 'SEARCH:'
	ctx.draw_text(1, y_offset, search_label)
	ctx.draw_text(1 + utf8_str_visible_length(search_label) + 1, y_offset, f_picker.search.query)
}

fn (mut f_picker FilePickerModal) draw_scrollable_list(mut ctx draw.Contextable, y_offset int, list []string) int {
	ctx.reset_bg_color()
	ctx.set_bg_color(r: 15, g: 15, b: 15)
	ctx.draw_rect(1, y_offset, ctx.window_width(), max_height)
	to := f_picker.resolve_to()
	for i := f_picker.from; i < to; i++ {
		ctx.set_bg_color(r: 15, g: 15, b: 15)
		if f_picker.current_sel_id == i {
			ctx.set_bg_color(r: 53, g: 53, b: 53)
			ctx.draw_rect(1, y_offset + (i - f_picker.from), ctx.window_width(), 1)
		}
		ctx.draw_text(1, y_offset + (i - f_picker.from), list[i])
	}
	return y_offset + (max_height - 2)
}

pub struct Action {
pub:
	op        ActionOp
	file_path string
}

pub enum ActionOp as u8 {
	no_op
	close_op
	open_file_op
}

pub fn (mut f_picker FilePickerModal) on_key_down(e draw.Event) Action {
	match e.code {
		.escape {
			return Action{ op: .close_op }
		}
		48...57, 97...122 {
			f_picker.search.put_char(e.ascii.ascii_str())
			f_picker.current_sel_id = 0
			f_picker.reorder_file_paths()
		}
		.down {
			f_picker.move_selection_down()
		}
		.up {
			f_picker.move_selection_up()
		}
		.enter {
			skip_byte_check := f_picker.special_mode
			return f_picker.file_selected(skip_byte_check)
		}
		.backspace {
			f_picker.search.backspace()
			f_picker.current_sel_id = 0
			f_picker.reorder_file_paths()
		}
		else {
			f_picker.search.put_char(e.ascii.ascii_str())
			f_picker.current_sel_id = 0
			f_picker.reorder_file_paths()
		}
	}
	return Action{ op: .no_op }
}

fn (mut f_picker FilePickerModal) move_selection_down() {
	file_paths := f_picker.file_paths
	f_picker.current_sel_id += 1
	to := f_picker.resolve_to()
	if f_picker.current_sel_id >= to {
		if file_paths.len - to > 0 {
			f_picker.from += 1
		}
	}
	if f_picker.current_sel_id >= file_paths.len {
		f_picker.current_sel_id = file_paths.len - 1
	}
}

fn (mut f_picker FilePickerModal) move_selection_up() {
	f_picker.current_sel_id -= 1
	if f_picker.current_sel_id < f_picker.from {
		f_picker.from -= 1
	}
	if f_picker.from < 0 {
		f_picker.from = 0
	}
	if f_picker.current_sel_id < 0 {
		f_picker.current_sel_id = 0
	}
}

fn (mut f_picker FilePickerModal) file_selected(skip_byte_check bool) Action {
	file_paths := f_picker.file_paths
	selected_path := file_paths[f_picker.current_sel_id]
	if !skip_byte_check && core.is_binary_file(selected_path) { return Action{ op: .no_op } }
	return Action{ op: .open_file_op, file_path: selected_path }
}

fn (mut f_picker FilePickerModal) reorder_file_paths() {
	query := f_picker.search.query
	f_picker.file_paths.sort_with_compare(fn [query] (a &string, b &string) int {
		a_score := score_value_by_query(query, a)
		b_score := score_value_by_query(query, b)
		if b_score > a_score  { return 1 }
		if a_score == b_score { return 0 }
		return -1
	})
}

fn (mut f_picker FilePickerModal) resolve_to() int {
	file_paths := f_picker.file_paths
	mut to := f_picker.from + max_height
	if to > file_paths.len {
		to = file_paths.len
	}
	return to
}

pub fn (f_picker FilePickerModal) is_open() bool { return f_picker.open }

pub fn (mut f_picker FilePickerModal) close() {
	f_picker.open = false
}

@[inline]
fn score_value_by_query(query string, value string) f32 {
	return f32(int(strings.dice_coefficient(query, value) * 1000)) / 1000
}

