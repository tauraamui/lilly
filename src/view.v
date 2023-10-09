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

const (
	block                   = "█"
	slant_left_flat_bottom  = ""
	left_rounded            = ""
	slant_left_flat_top     = ""
	slant_right_flat_bottom = ""
	right_rounded           = ""
	slant_right_flat_top    = ""

	status_green            = Color { 145, 237, 145 }
	status_orange           = Color { 237, 207, 123 }
	status_lilac            = Color { 194, 110, 230 }
	status_cyan             = Color { 138, 222, 237   }

	rune_digits             = [`0`, `1`, `2`, `3`, `4`, `5`, `6`, `7`, `8`, `9`]

	zero_width_unicode      = [
		`\u034f`, // U+034F COMBINING GRAPHEME JOINER
		`\u061c`, // U+061C ARABIC LETTER MARK
		`\u17b4`, // U+17B4 KHMER VOWEL INHERENT AQ
		`\u17b5`, // U+17B5 KHMER VOWEL INHERENT AA
		`\u200a`, // U+200A HAIR SPACE
		`\u200b`, // U+200B ZERO WIDTH SPACE
		`\u200c`, // U+200C ZERO WIDTH NON-JOINER
		`\u200d`, // U+200D ZERO WIDTH JOINER
		`\u200e`, // U+200E LEFT-TO-RIGHT MARK
		`\u200f`, // U+200F RIGHT-TO-LEFT MARK
		`\u2060`, // U+2060 WORD JOINER
		`\u2061`, // U+2061 FUNCTION APPLICATION
		`\u2062`, // U+2062 INVISIBLE TIMES
		`\u2063`, // U+2063 INVISIBLE SEPARATOR
		`\u2064`, // U+2064 INVISIBLE PLUS
		`\u206a`, // U+206A INHIBIT SYMMETRIC SWAPPING
		`\u206b`, // U+206B ACTIVATE SYMMETRIC SWAPPING
		`\u206c`, // U+206C INHIBIT ARABIC FORM SHAPING
		`\u206d`, // U+206D ACTIVATE ARABIC FORM SHAPING
		`\u206e`, // U+206E NATIONAL DIGIT SHAPES
		`\u206f`, // U+206F NOMINAL DIGIT SHAPES
		`\ufeff`, // U+FEFF ZERO WIDTH NO-BREAK SPACE
	]
)

enum Mode as u8 {
	normal
	visual
	insert
	command
}

fn (mode Mode) draw(mut ctx tui.Context) {
	label := mode.str()
	status_line_y := ctx.window_height - 1
	status_line_x := 1
	status_color := mode.color()
	mut offset := 0
	paint_shape_text(mut ctx, status_line_x + offset, status_line_y, status_color, "█")
	offset += 2
	ctx.bold()
	paint_text_on_background(mut ctx, status_line_x + offset, status_line_y, status_color, Color{ 0, 0, 0}, label)
	offset += label.len
	paint_shape_text(mut ctx, status_line_x + offset, status_line_y, status_color, "█")
	offset += 2
	paint_shape_text(mut ctx, status_line_x + offset, status_line_y, Color{ 25, 25, 25 }, "")
	ctx.set_bg_color(r: 25, g: 25, b: 25)
	ctx.draw_rect(12, ctx.window_height - 1, ctx.window_width - 1, ctx.window_height - 1)
	ctx.reset()
}

fn (mode Mode) color() Color {
	return match mode {
		.normal { status_green }
		.visual { status_lilac }
		.insert { status_orange }
		.command { status_cyan }
	}
}

fn (mode Mode) str() string {
	return match mode {
		.normal  { "NORMAL" }
		.visual  { "VISUAL" }
		.insert  { "INSERT" }
		.command { "COMMAND" }
	}
}

struct View {
mut:
	log             &log.Log
	mode            Mode
	lines           []string
	words           []string
	cursor          Cursor
	height          int
	from            int
	to              int
	show_whitespace bool
	cmd             string
}

fn (app &App) new_view() View {
	res := View{ log: app.log, mode: .normal, show_whitespace: false }
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
	view.height = ctx.window_height - 2

	view.draw_document(mut ctx)

	ctx.set_bg_color(r: 230, g: 230, b: 230)
	cursor_line := view.lines[view.from+view.cursor.pos.y]
	mut offset := 0
	mut scanto := view.cursor.pos.x
	if scanto + 1 > cursor_line.len { scanto = cursor_line.len - 1 }

	for c in cursor_line[..scanto+1] {
		match c {
			`\t` { offset += 4 }
			else { offset += 1 }
		}
	}
	ctx.draw_point(offset, view.cursor.pos.y+1)

	view.mode.draw(mut ctx)

	ctx.draw_text(1, ctx.window_height, view.cmd)
}

fn (mut view View) draw_document(mut ctx tui.Context) {
	mut to := view.height + view.from
	if to > view.lines.len { to = view.lines.len }
	view.to = to
	ctx.set_bg_color(r: 53, g: 53, b: 53)
	ctx.draw_rect(0, view.cursor.pos.y+1, ctx.window_width - 1, view.cursor.pos.y+1)
	for i, line in view.lines[view.from..to] {
		if i == view.cursor.pos.y { ctx.set_bg_color(r: 53, g: 53, b: 53) } else { ctx.reset_bg_color() }
		mut line_cpy := line
		if !view.show_whitespace {
			line_cpy = line_cpy.replace("\t", " ".repeat(4))
			mut max_width := ctx.window_width
			if max_width > line_cpy.len { max_width = line_cpy.len }
			ctx.draw_text(1, i+1, line_cpy[..max_width])
			continue
		}
		view.draw_line_show_whitespace(mut ctx, i, line_cpy)
	}
}

fn (mut view View) draw_line_show_whitespace(mut ctx tui.Context, i int, line_cpy string) {
	if i == view.cursor.pos.y {
		mut xx := 0
		for ci, c in line_cpy {
			if ci > ctx.window_width { return }
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
		for ci, c in line_cpy {
			if ci > ctx.window_width { return }
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

struct Color {
	r u8
	g u8
	b u8
}

fn paint_shape_text(mut ctx tui.Context, x int, y int, color Color, text string) {
	ctx.set_color(r: color.r, g: color.g, b: color.b)
	ctx.reset_bg_color()
	ctx.draw_text(x, y, text)
}

fn paint_text_on_background(mut ctx tui.Context, x int, y int, bg_color Color, fg_color Color, text string) {
	ctx.set_bg_color(r: bg_color.r, g: bg_color.g, b: bg_color.b)
	ctx.set_color(r: fg_color.r, g: fg_color.g, b: fg_color.b)
	ctx.draw_text(x, y, text)
}

fn (mut view View) cmd_put_char(c string) {
	view.cmd = "${view.cmd}${c}"
}

fn (mut view View) on_key_down(e &tui.Event) {
	match view.mode {
		.normal {
			match e.code {
				.h { view.h() }
				.l { view.l() }
				.j { view.j() }
				.k { view.k() }
				.i { if view.mode == .normal { view.i() } }
				.colon { if view.mode == .normal { view.cmd() } }
				.left_square_bracket { if e.modifiers == .ctrl { view.mode = .normal } }
				.enter {
					if view.mode == .command {
						if view.cmd == ":q" { exit(0) }
						view.cmd = "unrecognised command ${view.cmd}"
					}
				}
				48...57, 97...122 { // 0-9a-zA-Z
					if view.mode == .command {
						view.cmd_put_char(e.ascii.ascii_str())
					}
					// buffer.put(e.ascii.ascii_str())
					/*
					if e.modifiers == .ctrl {
						if e.code == .left_bracket {
							view.mode = .normal
						}
					} else if !(e.modifiers.has(.ctrl | .alt) || e.code == .null) {
					}
					*/
				}
				else {}
			}
		}
		.command {
			match e.code {
				.left_square_bracket { if e.modifiers == .ctrl { view.mode = .normal } }
				.enter { if view.cmd == ":q" { exit(0) }; view.cmd = "unknown cmd ${view.cmd}"; view.mode = .normal }
				48...57, 97...122 { // 0-9a-zA-Z
					view.cmd_put_char(e.ascii.ascii_str())
				}
				else {}
			}
		}
		else {}
	}
}

fn (mut view View) i() {
	view.mode = .insert
}

fn (mut view View) cmd() {
	view.mode = .command
	view.cmd = ":"
}

fn (mut view View) h() {
	if view.mode == .insert || view.mode == .command { return }
	view.cursor.pos.x -= 1
	if view.cursor.pos.x < 0 { view.cursor.pos.x = 0 }
}

fn (mut view View) l() {
	if view.mode == .insert || view.mode == .command { return }
	view.cursor.pos.x += 1
	line_len := view.lines[view.from+view.cursor.pos.y].len
	if view.cursor.pos.x > line_len - 1 { view.cursor.pos.x = line_len - 1 }
}

fn (mut view View) j() {
	if view.mode == .insert || view.mode == .command { return }
	view.cursor.pos.y += 1
	if view.cursor.pos.y > view.height - 1 {
		view.cursor.pos.y = view.height - 1
		if view.lines.len - view.to > 0 {
			view.from += 1
		}
	}
	line_len := view.lines[view.from+view.cursor.pos.y].len
	if view.cursor.pos.x > line_len - 1 { view.cursor.pos.x = line_len - 1 }
}

fn (mut view View) k() {
	if view.mode == .insert || view.mode == .command { return }
	view.cursor.pos.y -= 1
	if view.cursor.pos.y < 0 {
		view.cursor.pos.y = 0
		view.from -= 1
		if view.from < 0 { view.from = 0 }
	}
	line_len := view.lines[view.from+view.cursor.pos.y].len
	if view.cursor.pos.x > line_len - 1 { view.cursor.pos.x = line_len - 1 }
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

