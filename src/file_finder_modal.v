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
	ctx.clear()
	ctx.set_color(r: 245, g: 245, b: 245)
	ctx.draw_text(1, 1, "WORKSPACE FILES")
	for i, l in file_finder_modal.file_paths.filter(fn (it string) bool {
		return !it.starts_with("./.git")
	}) {
		ctx.reset_bg_color()
		if i == file_finder_modal.current_selection {
			ctx.set_bg_color(r: 53, g: 53, b: 53)
		}
		ctx.draw_rect(1, i+2, ctx.window_width, i+2)
		ctx.draw_text(1, i+2, l)
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
}

fn (mut file_finder_modal FileFinderModal) move_selection_down(by int) {
	file_finder_modal.current_selection += 1
	if file_finder_modal.current_selection > file_finder_modal.file_paths.len - 1 { file_finder_modal.current_selection = 0 }
}

fn (mut file_finder_modal FileFinderModal) move_selection_up(by int) {
	file_finder_modal.current_selection -= 1
	if file_finder_modal.current_selection < 0 { file_finder_modal.current_selection = file_finder_modal.file_paths.len - 1 }
}
