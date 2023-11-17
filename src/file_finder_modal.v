module main

import term.ui as tui

struct FileFinderModal {
pub:
	file_paths []string
}

fn (file_finder_modal FileFinderModal) draw(mut ctx tui.Context) {
	ctx.clear()
	ctx.set_color(r: 245, g: 245, b: 245)
	ctx.draw_text(1, 1, "WORKSPACE FILES")
	for i, l in file_finder_modal.file_paths {
		ctx.draw_text(1, i+2, l)
	}
}

fn (file_finder_modal FileFinderModal) on_key_down(e &tui.Event, mut root Root) {
	match e.code {
		.escape { root.close_file_finder() }
		else { }
	}
}
