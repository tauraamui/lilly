module main

import term.ui as tui
import math
import strings

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
	mut offset_y := 1 + f64(ctx.window_height) * 0.1
	ctx.set_color(r: 245, g: 191, b: 243)
	for i, l in splash.logo.data {
		start_x := offset_x+(ctx.window_width / 2) - (l.runes().len / 2)
		if has_colouring_directives(l) {
			for j, c in l.runes() {
				mut to_draw := "${c}"
				if to_draw == "g" { to_draw = " "; ctx.set_color(r: 97, g: 242, b: 136) }
				if to_draw == "p" { to_draw = " "; ctx.set_color(r: 245, g: 191, b: 243) }
				ctx.draw_text(start_x + j, int(math.floor(offset_y))+i, to_draw)
			}
			continue
		}
		ctx.draw_text(offset_x+(ctx.window_width / 2) - (l.runes().len / 2), int(math.floor(offset_y))+i, l)
	}
	ctx.reset_color()

	offset_y += splash.logo.data.len
	offset_y += (ctx.window_height - offset_y) * 0.05

	offset_y += 2

	basic_command_help := [
		" Find File                   <leader>ff",
		" Find Word                   <leader>fg",
		" Recent Files                <leader>fo",
		" File Browser                <leader>fv",
		" Colorschemes                <leader>cs",
		" New File                    <leader>nf",
	]

	for h in basic_command_help {
		ctx.draw_text(offset_x+(ctx.window_width / 2) - (h.len / 2), int(math.floor(offset_y)), h)
		offset_y += 2
	}

	copyright_footer := "the lilly editor authors ©"
	ctx.draw_text(offset_x+(ctx.window_width / 2) - (copyright_footer.len / 2), int(math.floor(offset_y)), copyright_footer)
	ctx.hide_cursor()
}

fn has_colouring_directives(line string) bool {
	for i, c in line.split("") {
		if c == "g" || c == "p" { return true }
	}
	return false
}

pub fn (splash SplashScreen) on_key_down(e &tui.Event) {
	match e.code {
		.escape { exit(0) }
		else { }
	}
}

