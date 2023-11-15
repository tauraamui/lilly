module main

import term.ui as tui

const logo_contents = $embed_file("./src/splash-logo.txt")

struct Logo{
mut:
	data  []string
	width int
}

struct SplashScreen {
mut:
	logo Logo
}

pub fn new_splash() SplashScreen {
	mut splash := SplashScreen{
		logo: Logo{
			data: logo_contents.to_string().split_into_lines()
		}
	}

	for l in splash.logo.data {
		if l.len > splash.logo.width { splash.logo.width = l.len }
	}

	return splash
}

pub fn (splash SplashScreen) draw(mut ctx tui.Context) {
	offset_x := 1
	for i, l in splash.logo.data {
		ctx.draw_text(offset_x+(ctx.window_width / 2) - (l.runes().len / 2), i+1, l)
	}

	for x in 0..ctx.window_height {
		ctx.draw_text(offset_x + ctx.window_width / 2, x+1, "|")
	}
}

pub fn (splash SplashScreen) on_key_down(e &tui.Event) {
	match e.code {
		.escape { exit(0) }
		else { }
	}
}

