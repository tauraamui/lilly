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

struct View {
mut:
	log    &log.Log
	lines  []string
	words  []string
	cursor Cursor
	height int
	from   int
	to     int
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
	view.height = ctx.window_height

	ctx.set_bg_color(r: 53, g: 53, b: 53)
	ctx.draw_rect(0, view.cursor.pos.y+1, ctx.window_width - 1, view.cursor.pos.y+1)
	ctx.reset_bg_color()

	mut to := view.lines.len
	if to > view.height { to = view.height }
	view.to = to
	for i := view.from; i < to; i++ {
		ctx.draw_text(0, i+1, view.lines[i])
	}
	/*
	ctx.set_bg_color(r: 53, g: 53, b: 53)
	ctx.draw_rect(0, view.cursor.pos.y+1, ctx.window_width - 1, view.cursor.pos.y+1)

	mut to := view.lines.len
	to -= (to - view.height)
	to += view.from
	if to > view.lines.len { to = view.lines.len }
	view.to = to
	from := if view.from > view.lines.len { view.lines.len - 1 } else { view.from }
	for i, line in view.lines[from..to] {
		ctx.reset_bg_color()
		if i == view.cursor.pos.y {
			ctx.set_bg_color(r: 53, g: 53, b: 53)
		}
		ctx.draw_text(0, i+1, line)
	}
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
	if view.cursor.pos.y > view.to - 1 {
		view.cursor.pos.y = view.to - 1
	}
}

fn (mut view View) k() {
	view.cursor.pos.y -= 1
	if view.cursor.pos.y < view.from {
		view.cursor.pos.y = view.from
		view.from -= 1
		if view.from < 0 { view.from = 0 }
	}
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

