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
import regex

const max_height = 20

struct FileFinderModal {
pub:
	file_paths []string
mut:
	current_selection int
	from              int
	search            FileSearch
}

struct FileSearch {
mut:
	query    string
	cursor_x int
}

fn (mut file_search FileSearch) put_char(c string) {
	first := file_search.query[..file_search.cursor_x]
	last := file_search.query[file_search.cursor_x..]
	file_search.query = "${first}${c}${last}"
	file_search.cursor_x += 1
}

fn (mut file_search FileSearch) backspace() {
	if file_search.cursor_x == 0 { return }
	first := file_search.query[..file_search.cursor_x-1]
	last := file_search.query[file_search.cursor_x..]
	file_search.query = "${first}${last}"
	file_search.cursor_x -= 1
	if file_search.cursor_x < 0 { file_search.cursor_x = 0 }
}

fn (mut file_finder_modal FileFinderModal) draw(mut ctx tui.Context) {
	defer { ctx.reset_bg_color() }
	ctx.set_color(r: 245, g: 245, b: 245)
	ctx.set_bg_color(r: 15, g: 15, b: 15)
	mut y_offset := 1
	ctx.draw_text(1, y_offset, "=== FILE BROWSER ===")
	y_offset += 1
	ctx.set_cursor_position(1, y_offset + file_finder_modal.current_selection - file_finder_modal.from)
	y_offset += file_finder_modal.draw_scrollable_list(mut ctx, y_offset, file_finder_modal.resolve_file_paths())
}

fn (mut file_finder_modal FileFinderModal) draw_scrollable_list(mut ctx tui.Context, y_offset int, list []string) int {
	ctx.reset_bg_color()
	ctx.set_bg_color(r: 15, g: 15, b: 15)
	ctx.draw_rect(1, y_offset, ctx.window_width, y_offset+max_height - 1)
	to := file_finder_modal.resolve_to()
	for i := file_finder_modal.from; i < to; i++ {
		ctx.set_bg_color(r: 15, g: 15, b: 15)
		if file_finder_modal.current_selection == i {
			ctx.set_bg_color(r: 60, g: 60, b: 60)
			ctx.draw_rect(1, y_offset+(i - file_finder_modal.from), ctx.window_width, y_offset+(i - file_finder_modal.from))
		}
		ctx.draw_text(1, y_offset+(i - file_finder_modal.from), list[i])
	}
	return y_offset + (max_height - 1)
}

fn (mut file_finder_modal FileFinderModal) on_key_down(e &tui.Event, mut root Root) {
	match e.code {
		.escape    { root.close_file_finder() }
		.down      { file_finder_modal.move_selection_down() }
		.up        { file_finder_modal.move_selection_up() }
		.enter     { file_finder_modal.file_selected(mut root) }
		.backspace { file_finder_modal.search.backspace() }
		else { file_finder_modal.search.put_char(e.ascii.ascii_str()) }
	}
}

fn (file_finder_modal FileFinderModal) file_selected(mut root Root) {
	file_paths := file_finder_modal.resolve_file_paths()
	root.open_file(file_paths
		.filter(fn (it string) bool { return !it.starts_with("./.git") })[file_finder_modal.current_selection]) or { panic("${err}") }
}

fn (file_finder_modal FileFinderModal) resolve_file_paths() []string {
	if file_finder_modal.search.query.len == 0 { return file_finder_modal.file_paths }
	mut re := regex.regex_opt(file_finder_modal.search.query) or { return [] }
	return file_finder_modal.file_paths.filter(fn [mut re] (it string) bool {
		return re.find_all(it).len > 0
	})
}

fn (mut file_finder_modal FileFinderModal) resolve_to() int {
	file_paths := file_finder_modal.resolve_file_paths()
	mut to := file_finder_modal.from + max_height
	if to > file_paths.len { to = file_paths.len }
	return to
}

fn (mut file_finder_modal FileFinderModal) move_selection_down() {
	file_paths := file_finder_modal.resolve_file_paths()
	file_finder_modal.current_selection += 1
	to := file_finder_modal.resolve_to()
	if file_finder_modal.current_selection >= to {
		if file_paths.len - to > 0 {
			file_finder_modal.from += 1
		}
	}
	if file_finder_modal.current_selection >= file_paths.len {
		file_finder_modal.current_selection = file_paths.len - 1
	}
}

fn (mut file_finder_modal FileFinderModal) move_selection_up() {
	file_finder_modal.current_selection -= 1
	if file_finder_modal.current_selection < file_finder_modal.from {
		file_finder_modal.from -= 1
	}
	if file_finder_modal.from < 0 { file_finder_modal.from = 0 }
	if file_finder_modal.current_selection < 0 { file_finder_modal.current_selection = 0 }
}
