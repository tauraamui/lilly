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

struct FileFinderModal {
pub:
	file_paths              []string
mut:
	current_selection int
}

fn (file_finder_modal FileFinderModal) draw(mut ctx tui.Context) {
	defer { ctx.reset_bg_color() }
	ctx.set_color(r: 245, g: 245, b: 245)
	ctx.draw_text(1, 1, "WORKSPACE FILES")
	for i, l in file_finder_modal.file_paths.filter(fn (it string) bool {
		return !it.starts_with("./.git")
	}) {
		ctx.reset_bg_color()
		ctx.set_bg_color(r: 15, g: 15, b: 15)
		if i == file_finder_modal.current_selection {
			ctx.set_bg_color(r: 53, g: 53, b: 53)
		}
		ctx.draw_rect(1, i+2, ctx.window_width, i+2)
		ctx.draw_text(1, i+2, l)
	}
	ctx.set_cursor_position(1, file_finder_modal.current_selection + 2)
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

fn (mut file_finder_modal FileFinderModal) move_selection_down(by int) {
	file_finder_modal.current_selection += 1
	if file_finder_modal.current_selection > file_finder_modal.file_paths.len - 1 { file_finder_modal.current_selection = 0 }
}

fn (mut file_finder_modal FileFinderModal) move_selection_up(by int) {
	file_finder_modal.current_selection -= 1
	if file_finder_modal.current_selection < 0 { file_finder_modal.current_selection = file_finder_modal.file_paths.len - 1 }
}
