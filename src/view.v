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

	mut to := view.height + view.from
	if to > view.lines.len { to = view.lines.len }
	view.to = to
	for i, line in view.lines[view.from..to] {
		line_cpy := line
		if i == view.cursor.pos.y {
			ctx.set_bg_color(r: 53, g: 53, b: 53)
			ctx.draw_rect(0, view.cursor.pos.y+1, ctx.window_width - 1, view.cursor.pos.y+1)
			mut xx := 0
			for c in line_cpy {
				match c {
					`\t` {
						ctx.set_color(r: 120, g: 120, b: 120)
						ctx.draw_text(xx+1, i+1, "->->")
						ctx.reset_color()
						xx += 4
					}
					` ` {
						ctx.set_color(r: 120, g: 120, b: 120)
						ctx.draw_text(xx+1, i+1, "·")
						ctx.reset_color()
						xx += 1
					}
					else {
						ctx.draw_text(xx+1, i+1, c.ascii_str())
						xx += 1
					}
				}
			}
			ctx.reset_bg_color()
		} else {
			mut xx := 0
			for c in line_cpy {
				match c {
					`\t` {
						ctx.set_color(r: 120, g: 120, b: 120)
						ctx.draw_text(xx+1, i+1, "->->")
						ctx.reset_color()
						xx += 4
					}
					` ` {
						ctx.set_color(r: 120, g: 120, b: 120)
						ctx.draw_text(xx+1, i+1, "·")
						ctx.reset_color()
						xx += 1
					}
					else {
						ctx.draw_text(xx+1, i+1, c.ascii_str())
						xx += 1
					}
				}
			}
		}
	}
	ctx.set_bg_color(r: 230, g: 230, b: 230)
	cursor_line := view.lines[view.from+view.cursor.pos.y]
	mut offset := 0
	if cursor_line.len > 0  {
		mut scanto := view.cursor.pos.x
		if scanto + 1 > cursor_line.len { scanto = cursor_line.len - 1 }

		for c in cursor_line[..scanto+1] {
			match c {
				`\t` { offset += 4 }
				else { offset += 1 }
			}
		}
		ctx.draw_point(offset, view.cursor.pos.y+1)
	}
	ctx.reset_bg_color()
}

fn (mut view View) on_key_down(e &tui.Event) {
	match e.code {
		.escape { exit(0) }
		.h { view.h() }
		.l { view.l() }
		.j { view.j() }
		.k { view.k() }
		else {}
	}
}

fn (mut view View) h() {
	view.cursor.pos.x -= 1
	if view.cursor.pos.x < 0 { view.cursor.pos.x = 0 }
	/*
	line := view.lines[view.from+view.cursor.pos.y]
	if line.len > 0 {
		view.cursor.pos.x -= 1
	}
	if view.cursor.pos.x < 0 { view.cursor.pos.x = 0 }
	*/
}

fn (mut view View) l() {
	view.cursor.pos.x += 1
	line_len := view.lines[view.from+view.cursor.pos.y].len
	if view.cursor.pos.x > line_len - 1 { view.cursor.pos.x = line_len - 1 }
}

fn (mut view View) j() {
	view.cursor.pos.y += 1
	if view.cursor.pos.y > view.height - 1 {
		view.cursor.pos.y = view.height - 1
		if view.lines.len - view.to > 0 {
			view.from += 1
		}
	}
	/*
	line := view.lines[view.from+view.cursor.pos.y]
	if view.cursor.pos.x > line.len - 1 { view.cursor.pos.x = line.len - 1}
	*/
}

fn (mut view View) k() {
	view.cursor.pos.y -= 1
	if view.cursor.pos.y < 0 {
		view.cursor.pos.y = 0
		view.from -= 1
		if view.from < 0 { view.from = 0 }
	}
	/*
	line := view.lines[view.from+view.cursor.pos.y]
	if view.cursor.pos.x > line.len - 1 { view.cursor.pos.x = line.len - 1 }
	*/
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

