module main

import os
import term.ui as tui
import log

struct Cursor {
mut:
	pos Pos
}

struct Pos {
mut:
	x int
	y int
}

fn (cursor Cursor) draw(mut ctx tui.Context) {
	ctx.draw_rect(0, cursor.pos.y, ctx.window_width - 1, cursor.pos.y)
}

struct View {
mut:
	log    &log.Log
	lines  []string
	words  []string
	cursor Cursor
	from   int
}

fn (app &App) new_view() View {
	res := View{ log: app.log }
	return res
}

fn (mut view View) open_file(path string) {
	view.lines = os.read_lines(path) or { []string{} }
	// get words map
	if view.lines.len < 1000 {
		println('getting words')
		for line in view.lines {
			words := get_clean_words(line)
			for word in words {
				if word !in view.words {
					view.words << word
				}
			}
		}
	}
	// empty file, handle it
	if view.lines.len == 0 {
		view.lines << ''
	}
}

fn (mut view View) draw(mut ctx tui.Context) {
	mut y := ctx.window_height - 1
	y = if y > view.lines.len { view.lines.len } else { y }

	for i, line in view.lines[..y] {
		if i == view.cursor.pos.y {
			ctx.set_bg_color(r: 53, g: 53, b: 53)
			ctx.draw_rect(0, i+1, ctx.window_width - 1, i+1)
		}
		ctx.draw_text(0, i+1, line)
		ctx.reset_bg_color()
	}

	/*
	for i := 0; i < y; i++ {
		mut line_cpy := view.lines[i]

		if i == view.cursor.pos.y {
			ctx.set_bg_color(r: 53, g: 53, b: 53)
			view.cursor.draw(mut ctx)

			view.log.debug("[${i}] LINE LEN: ${line_cpy.len} WIN WIDTH: ${ctx.window_width}")
			view.log.flush()
		}

		if line_cpy.len == 0 { ctx.set_bg_color(r: 230, g: 20, b: 20) }
		ctx.draw_text(0, i, line_cpy)
		if line_cpy.len == 0 { view.log.debug("${i} is blank"); view.log.flush() }
	}
		ctx.reset_bg_color()
		*/
}

fn (mut view View) on_key_down(e &tui.Event) {
	match e.code {
		.escape { exit(0) }
		.j { view.j() }
		.k { view.k() }
		else {}
	}
}

fn (mut view View) j() {
	view.cursor.pos.y += 1
}

fn (mut view View) k() {
	view.cursor.pos.y -= 1; if view.cursor.pos.y < 0 { view.cursor.pos.y = 0 }
}

fn get_clean_words(line string) []string {
	mut res := []string{}
	mut i := 0
	for i < line.len {
		// Skip bad first
		for i < line.len && !is_alpha_underscore(int(line[i])) {
			i++
		}
		// Read all good
		start2 := i
		for i < line.len && is_alpha_underscore(int(line[i])) {
			i++
		}
		// End of word, save it
		word := line[start2..i]
		res << word
		i++
	}
	return res
}

fn is_alpha(r u8) bool {
	return (r >= `a` && r <= `z`) || (r >= `A` && r <= `Z`) || (r >= `0` && r <= `9`)
}

fn is_whitespace(r u8) bool {
	return r == ` ` || r == `\t`
}

fn is_alpha_underscore(r int) bool {
	return is_alpha(u8(r)) || u8(r) == `_` || u8(r) == `#` || u8(r) == `$`
}

