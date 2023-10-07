module main

import os
import term.ui as tui

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
    ctx.set_bg_color(r: 53, g: 53, b: 53)
	ctx.draw_rect(0, cursor.pos.y, ctx.window_width - 1, cursor.pos.y)
	ctx.reset()
}

struct View {
mut:
	lines  []string
	words  []string
	cursor Cursor
	from   int
}

fn (app &App) new_view() View {
	res := View{}
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

fn (view View) draw(mut ctx &tui.Context) {
	//view.cursor.draw(mut ctx)
	mut y := ctx.window_height
	y = if y > view.lines.len { view.lines.len } else { y }
	for i := 0; i < y; i++ {
		// if i == view.cursor.pos.y { ctx.set_bg_color(r: 53, g: 53, b: 53) } else { ctx.reset() }
		mut line := view.lines[i]
		if line.len > ctx.window_width {
			line = line[..ctx.window_width]
		}
		ctx.draw_text(0, i, line)
	}
}

fn (mut view View) on_key_down(e &tui.Event) {
	match e.code {
		.escape { exit(0) }
		.j { view.cursor.pos.y += 1 }
		.k { view.cursor.pos.y -= 1; if view.cursor.pos.y < 1 { view.cursor.pos.y = 1 } }
		else {}
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

