module main

import term.ui as tui

struct FileFinderModal {}

fn (file_finder_modal FileFinderModal) draw(mut ctx tui.Context) {
	ctx.clear()
}

fn (file_finder_modal FileFinderModal) on_key_down(e &tui.Event, mut root Root) {
	match e.code {
		.escape { root.close_file_finder() }
		else { }
	}
}
