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

const max_height = 20

struct FileFinderModal {
pub:
	file_paths []string
mut:
	current_selection int
	from       int
}

fn (mut file_finder_modal FileFinderModal) draw(mut ctx tui.Context) {
	defer { ctx.reset_bg_color() }
	ctx.set_color(r: 245, g: 245, b: 245)
	ctx.set_bg_color(r: 15, g: 15, b: 15)
	mut y_offset := 1
	ctx.draw_text(1, y_offset, "=== FILE BROWSER ===")
	y_offset += 1
	file_finder_modal.draw_scrollable_list(mut ctx, y_offset, file_finder_modal.file_paths)
	ctx.set_cursor_position(1, y_offset + file_finder_modal.current_selection)
}

fn (mut file_finder_modal FileFinderModal) draw_scrollable_list(mut ctx tui.Context, y_offset int, list []string) {
	ctx.reset_bg_color()
	ctx.set_bg_color(r: 15, g: 15, b: 15)
	ctx.draw_rect(1, y_offset, ctx.window_width, y_offset+max_height - 1)
	from, to := file_finder_modal.resolve_from_and_to()
	for i := from; i < to; i++ {
		ctx.draw_text(1, y_offset+(i - from), list[i])
	}
}

fn (mut file_finder_modal FileFinderModal) on_key_down(e &tui.Event, mut root Root) {
	match e.code {
		.escape { root.close_file_finder() }
		.j      { file_finder_modal.move_selection_down(1) }
		.k      { file_finder_modal.move_selection_up(1) }
		.enter  { file_finder_modal.file_selected(mut root) }
		else { }
	}
}

fn (file_finder_modal FileFinderModal) file_selected(mut root Root) {
	root.open_file(file_finder_modal.file_paths
		.filter(fn (it string) bool { return !it.starts_with("./.git") })[file_finder_modal.current_selection]) or { panic("${err}") }
}

fn (mut file_finder_modal FileFinderModal) resolve_from_and_to() (int, int) {
	mut to := file_finder_modal.file_paths.len
	if to > max_height { to = max_height }
	return file_finder_modal.from, to
}

fn (mut file_finder_modal FileFinderModal) move_selection_down(by int) {
	file_finder_modal.current_selection += 1
	_, to := file_finder_modal.resolve_from_and_to()
	if file_finder_modal.current_selection > to - 1 { file_finder_modal.current_selection = to - 1}
}

fn (mut file_finder_modal FileFinderModal) move_selection_up(by int) {
	file_finder_modal.current_selection -= 1
	from, _ := file_finder_modal.resolve_from_and_to()
	if file_finder_modal.current_selection < from - 1 { file_finder_modal.current_selection = from}
}
