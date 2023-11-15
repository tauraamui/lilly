module main

import term.ui as tui

struct SplashScreen {}

pub fn (splash SplashScreen) draw(mut ctx tui.Context) {
	ctx.draw_text(1, 1, "LILLY EDITOR")
}

pub fn (splash SplashScreen) on_key_down(e &tui.Event) {
	match e.code {
		.escape { exit(0) }
		else { }
	}
}

