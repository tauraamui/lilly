module main

import os
import term.ui as tui
import log
import datatypes
import strconv

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
	paint_text_on_background(mut ctx, status_line_x + offset, status_line_y, status_color, Color{ 0, 0, 0}, label)
	offset += label.len
	paint_shape_text(mut ctx, status_line_x + offset, status_line_y, status_color, "█")
	offset += 2
	paint_shape_text(mut ctx, status_line_x + offset, status_line_y, Color{ 25, 25, 25 }, "")
	ctx.set_bg_color(r: 25, g: 25, b: 25)
	ctx.draw_rect(12, ctx.window_height - 1, ctx.window_width, ctx.window_height - 1)
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
		.normal  { "NORMAL"  }
		.visual  { "VISUAL"  }
		.insert  { "INSERT"  }
		.command { "COMMAND" }
	}
}

struct View {
mut:
	log                      &log.Log
	mode                     Mode
	buffer                   Buffer
	cursor                   Cursor
	cmd_buf                  CmdBuffer
	repeat_amount               string
	x                        int
	width                    int
	height                   int
	from                     int
	to                       int
	show_whitespace          bool
	left_bracket_press_count int
	right_bracket_press_count int
}

struct Buffer {
mut:
	lines []string
}

struct CmdBuffer {
mut:
	line        string
	err_msg     string
	cursor_x    int
	cursor_y    int
	cmd_history datatypes.Queue[string]
}

fn (mut cmd_buf CmdBuffer) draw(mut ctx tui.Context, draw_cursor bool) {
	defer { ctx.reset_bg_color() }
	if cmd_buf.err_msg.len > 0 {
		ctx.set_color(r: 230, g: 110, b: 100)
		ctx.draw_text(1, ctx.window_height, cmd_buf.err_msg)
		ctx.reset_color()
		return
	}
	ctx.draw_text(1, ctx.window_height, cmd_buf.line)
	if draw_cursor {
		ctx.set_bg_color(r: 230, g: 230, b: 230)
		ctx.draw_point(cmd_buf.cursor_x+1, ctx.window_height)
	}
}

fn (mut cmd_buf CmdBuffer) prepare_for_input() {
	cmd_buf.err_msg = ""
	cmd_buf.line = ":"
	cmd_buf.cursor_x = 1
}

fn (mut cmd_buf CmdBuffer) exec(mut view View) {
	success := match view.cmd_buf.line {
		":q" { exit(0); true }
		":toggle whitespace" { view.show_whitespace = !view.show_whitespace; true }
		else { false }
	}
	if success {
		if cmd_buf.cmd_history.last() or { "" } == cmd_buf.line { return }
		cmd_buf.cmd_history.push(cmd_buf.line)
		return
	}
	cmd_buf.set_error("unrecognised command ${cmd_buf.line}")
}

fn (mut cmd_buf CmdBuffer) put_char(c string) {
	first := cmd_buf.line[..cmd_buf.cursor_x]
	last  := cmd_buf.line[cmd_buf.cursor_x..]
	cmd_buf.line = "${first}${c}${last}"
	cmd_buf.cursor_x += 1
}

fn (mut cmd_buf CmdBuffer) up() {
	cmd_buf.cursor_y -= 1
	if cmd_buf.cursor_y < 0 { cmd_buf.cursor_y = 0 }
	if cmd_buf.cmd_history.len() > 0 {
		cmd_buf.line = cmd_buf.cmd_history.index(cmd_buf.cursor_y) or { ":" }
		cmd_buf.cursor_x = cmd_buf.line.len
	}
}

fn (mut cmd_buf CmdBuffer) left() {
	cmd_buf.cursor_x -= 1
	if cmd_buf.cursor_x <= 0 { cmd_buf.cursor_x = 0 }
}

fn (mut cmd_buf CmdBuffer) right() {
	cmd_buf.cursor_x += 1
	if cmd_buf.cursor_x > cmd_buf.line.len { cmd_buf.cursor_x = cmd_buf.line.len }
}

fn (mut cmd_buf CmdBuffer) backspace() {
	if cmd_buf.cursor_x == 0 { return }
	first := cmd_buf.line[..cmd_buf.cursor_x-1]
	last  := cmd_buf.line[cmd_buf.cursor_x..]
	cmd_buf.line = "${first}${last}"
	cmd_buf.cursor_x -= 1
	if cmd_buf.cursor_x < 0 { cmd_buf.cursor_x = 0 }
}

fn (mut cmd_buf CmdBuffer) set_error(msg string) {
	cmd_buf.line = ""
	cmd_buf.err_msg = msg
}

fn (mut cmd_buf CmdBuffer) clear() {
	cmd_buf.line = ""
	cmd_buf.cursor_x = 0
}

fn (app &App) new_view() View {
	res := View{ log: app.log, mode: .normal, show_whitespace: false }
	return res
}

fn (mut view View) open_file(path string) {
	view.buffer.lines = os.read_lines(path) or { []string{} }
	// get words map
	/*
	if view.buffer.lines.len < 1000 {
		println('getting words')
		for line in view.buffer.lines {
			words := get_clean_words(line)
			for word in words {
				if word !in view.words {
					view.words << word
				}
			}
		}
	}
	*/
	// empty file, handle it
	if view.buffer.lines.len == 0 {
		view.buffer.lines << ''
	}
}

fn (mut view View) draw(mut ctx tui.Context) {
	view.height = ctx.window_height
	view.x = "${view.buffer.lines.len}".len + 1
	view.width = ctx.window_width
	view.width -= view.x

	view.draw_document(mut ctx)

	ctx.set_bg_color(r: 230, g: 230, b: 230)
	cursor_line := view.buffer.lines[view.cursor.pos.y]
	mut offset := 0
	mut scanto := view.cursor.pos.x
	if scanto + 1 > cursor_line.len { scanto = cursor_line.len - 1 }

	for c in cursor_line[..scanto+1] {
		match c {
			`\t` { offset += 4 }
			else { offset += 1 }
		}
	}
	if cursor_line.len == 0 { offset += 1 }
	mut cursor_screen_space_y := view.cursor.pos.y - view.from
	if cursor_screen_space_y > view.code_view_height() - 1 { cursor_screen_space_y = view.code_view_height() - 1 }
	ctx.draw_point(view.x+offset, cursor_screen_space_y+1)

	view.mode.draw(mut ctx)
	view.cmd_buf.draw(mut ctx, view.mode == .command)

	ctx.draw_text(ctx.window_width-view.repeat_amount.len, ctx.window_height, view.repeat_amount)
}

fn (mut view View) draw_document(mut ctx tui.Context) {
	mut to := view.from + view.code_view_height()
	if to > view.buffer.lines.len { to = view.buffer.lines.len }
	view.to = to
	ctx.set_bg_color(r: 53, g: 53, b: 53)

	mut cursor_screen_space_y := view.cursor.pos.y - view.from
	if cursor_screen_space_y > view.code_view_height() - 1 { cursor_screen_space_y = view.code_view_height() - 1 }
	ctx.draw_rect(view.x+1, cursor_screen_space_y+1, ctx.window_width - 1, cursor_screen_space_y+1)
	for y, line in view.buffer.lines[view.from..to] {
		ctx.reset_bg_color()
		mut line_cpy := line
		ctx.set_color(r: 117, g: 118, b: 120)
		line_num_str := "${view.from+y}"
		ctx.draw_text(view.x - line_num_str.len, y+1, line_num_str)
		ctx.reset_color()
		if y == cursor_screen_space_y { ctx.set_bg_color(r: 53, g: 53, b: 53) }
		if !view.show_whitespace {
			line_cpy = line_cpy.replace("\t", " ".repeat(4))
			mut max_width := view.width
			if max_width > line_cpy.len { max_width = line_cpy.len }
			ctx.draw_text(view.x+1, y+1, line_cpy[..max_width])
			continue
		}
		view.draw_line_show_whitespace(mut ctx, y, line_cpy)
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
					ctx.draw_text(view.x+xx+1, i+1, "->->")
					ctx.reset_color()
					xx += 4
				}
				` ` {
					ctx.set_color(r: 120, g: 120, b: 120)
					ctx.draw_text(view.x+xx+1, i+1, "·")
					ctx.reset_color()
					xx += 1
				}
				else {
					ctx.draw_text(view.x+xx+1, i+1, c.ascii_str())
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
					ctx.draw_text(view.x+xx+1, i+1, "->->")
					ctx.reset_color()
					xx += 4
				}
				` ` {
					ctx.set_color(r: 120, g: 120, b: 120)
					ctx.draw_text(view.x+xx+1, i+1, "·")
					ctx.reset_color()
					xx += 1
				}
				else {
					ctx.draw_text(view.x+xx+1, i+1, c.ascii_str())
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

fn (mut view View) on_key_down(e &tui.Event) {
	match view.mode {
		.normal {
			match e.code {
				.h { view.h() }
				.l { view.l() }
				.j { view.j() }
				.k { view.k() }
				.i { view.i() }
				.e { view.e() } // TODO:(tauraamui) -> implement
				.w { view.w() } // TODO:(tauraamui) -> implement
				// .b { view.b() } // TODO:(tauraamui) -> implement
				.left_curly_bracket { view.jump_cursor_up_to_next_blank_line() }
				.right_curly_bracket { view.jump_cursor_down_to_next_blank_line() }
				.colon { view.cmd() }
				.left_square_bracket { view.left_square_bracket() }
				.right_square_bracket { view.right_square_bracket() }
				.escape { view.escape() }
				.enter {
					if view.mode == .command {
						if view.cmd_buf.line == ":q" { exit(0) }
						view.cmd_buf.set_error("unrecognised command ${view.cmd_buf.line}")
					}
				}
				48...57 { // 0-9a
					view.repeat_amount = "${view.repeat_amount}${e.ascii.ascii_str()}"
				}
				else {}
			}
		}
		.command {
			match e.code {
				.left_square_bracket { if e.modifiers == .ctrl { view.escape() } }
				.escape { view.escape() }
				.enter { view.cmd_buf.exec(mut view); view.mode = .normal }
				.space { view.cmd_buf.put_char(" ") }
				48...57, 97...122 { // 0-9a-zA-Z
					view.cmd_buf.put_char(e.ascii.ascii_str())
				}
				.left { view.cmd_buf.left() }
				.right { view.cmd_buf.right() }
				.up { view.cmd_buf.up() }
				.down { return }
				.backspace { view.cmd_buf.backspace() }
				else {
					view.cmd_buf.put_char(e.ascii.ascii_str())
				}
			}
		}
		.insert {
			match e.code {
				.left_square_bracket { if e.modifiers == .ctrl { view.escape() } }
				.escape { view.escape() }
				else {}
			}
		}
		.visual {
			match e.code {
				.left_square_bracket { if e.modifiers == .ctrl { view.escape() } }
				.escape { view.escape() }
				else {}
			}
		}
	}
}

fn (mut view View) escape() {
	view.mode = .normal
	view.repeat_amount = ""
	view.cmd_buf.clear()
}

fn (mut view View) move_cursor_up(amount int) {
	view.cursor.pos.y -= amount
	view.clamp_cursor_within_document_bounds()
	view.scroll_from_and_to()
}

fn (mut view View) move_cursor_down(amount int) {
	view.cursor.pos.y += amount
	view.clamp_cursor_within_document_bounds()
	view.scroll_from_and_to()
}

fn (mut view View) scroll_from_and_to() {
	if view.cursor.pos.y < view.from {
		diff := view.from - view.cursor.pos.y
		view.from -= diff
		if view.from < 0 { view.from = 0 }
		return
	}

	if view.cursor.pos.y+1 > view.to {
		diff := view.cursor.pos.y+1 - view.to
		view.from += diff
	}
}

fn (mut view View) clamp_cursor_within_document_bounds() {
	if view.cursor.pos.y < 0 { view.cursor.pos.y = 0}
	if view.cursor.pos.y > view.buffer.lines.len - 1 { view.cursor.pos.y = view.buffer.lines.len - 1 }
}

fn (mut view View) clamp_cursor_x_pos() {
	line_len := view.buffer.lines[view.cursor.pos.y].len
	if line_len == 0 { view.cursor.pos.x = 0; return }
	if view.cursor.pos.x > line_len - 1 { view.cursor.pos.x = line_len - 1 }
	if view.cursor.pos.x < 0 { view.cursor.pos.x = 0 }
}

fn (view View) code_view_height() int { return view.height - 2 }

fn (mut view View) cmd() {
	view.mode = .command
	view.cmd_buf.prepare_for_input()
}

fn (mut view View) exec_cmd() bool {
	return match view.cmd_buf.line {
		":q" { exit(0); true }
		":toggle whitespace" { view.show_whitespace = !view.show_whitespace; true }
		else { false }
	}
}

fn (mut view View) h() {
	view.cursor.pos.x -= 1
	view.clamp_cursor_x_pos()
}

fn (mut view View) l() {
	view.cursor.pos.x += 1
	view.clamp_cursor_x_pos()
}

fn (mut view View) j() {
	defer { view.repeat_amount = "" }
	count := strconv.atoi(view.repeat_amount) or { 1 }
	view.move_cursor_down(count)
	view.clamp_cursor_x_pos()
}

fn (mut view View) k() {
	defer { view.repeat_amount = "" }
	count := strconv.atoi(view.repeat_amount) or { 1 }
	view.move_cursor_up(count)
	view.clamp_cursor_x_pos()
}

fn (mut view View) i() {
	view.mode = .insert
}

fn (mut view View) w() {
	line := view.buffer.lines[view.cursor.pos.y]
	view.cursor.pos.x += calc_w_move_amount(view.cursor.pos, line)
	view.clamp_cursor_x_pos()
}

fn calc_w_move_amount(cursor_pos Pos, line string) int {
	if line.len == 0 { return 0 }
	mut next_whitespace := 0
	for i, c in line[cursor_pos.x..] {
		if is_whitespace(c) { next_whitespace = i; break }
	}

	mut next_alpha := 0
	for i, c in line[cursor_pos.x+next_whitespace..] {
		if !is_whitespace(c) { next_alpha = i; break }
	}
	return next_whitespace + next_alpha
}

fn (mut view View) e() {
	line := view.buffer.lines[view.cursor.pos.y]
	view.cursor.pos.x += calc_e_move_amount(view.cursor.pos, line)
	view.clamp_cursor_x_pos()
}

fn calc_e_move_amount(cursor_pos Pos, line string) int {
    if line.len == 0 { return 0 }

	if is_whitespace(line[cursor_pos.x]) {
		mut word_start_offset := 0
		for i, c in line[cursor_pos.x..] {
			if !is_whitespace(c) { word_start_offset = i; break }
			if cursor_pos.x + i == line.len - 1 { word_start_offset = i; break }
		}

		mut word_end_offset := 0
		for i, c in line[cursor_pos.x+word_start_offset..] {
			if is_whitespace(c) { word_end_offset = i - 1; break }
			if cursor_pos.x + word_start_offset + i == line.len - 1 { word_end_offset = i; break }
		}

		return word_start_offset + word_end_offset
	}

	if !is_whitespace(line[cursor_pos.x]) {
		mut word_start_offset := 0
		mut word_end_offset := 0
		for i, c in line[cursor_pos.x..] {
			if is_whitespace(c) { word_end_offset = i - 1; break }
		}

		// already at end of a word, find the start of next word
		if word_end_offset == 0 {
			for i, c in line[cursor_pos.x..] {
				if i > 0 && !is_whitespace(c) { word_start_offset = i; break }
			}

			// find the end of this word
			word_end_offset = 0
			for i, c in line[cursor_pos.x+word_start_offset..] {
				if is_whitespace(c) { word_end_offset = i - 1; break }
				if cursor_pos.x + word_start_offset + i == line.len - 1 { word_end_offset = i; break }
			}

			return word_start_offset + word_end_offset
		}

		return word_end_offset
	}

	return 0
}

fn calc_b_move_amount(cursor_pos Pos, line string) int {
    if line.len == 0 || cursor_pos.x == 0 { return 0 }

	if !is_whitespace(line[cursor_pos.x]) {
		mut word_start_offset := 0
		for i := cursor_pos.x - 1; i > 0; i-- {
			if is_whitespace(line[i]) { break }
			word_start_offset += 1
		}

		// we're already at the start of this word, find the end of the previous word
		if word_start_offset == 0 {
			mut word_end_offset := 0
			for i := cursor_pos.x - 1; i > 0; i-- {
				if !is_whitespace(line[i]) { break }
				word_end_offset += 1
			}

			// first start of this word
			word_start_offset = 0
			for i := cursor_pos.x - 1 - word_end_offset; i > 0; i-- {
				if is_whitespace(line[i]) { break }
				word_start_offset += 1
			}

			return word_end_offset + word_start_offset
		}

		return word_start_offset
	}

	return -1
}

fn (mut view View) jump_cursor_up_to_next_blank_line() {
	view.clamp_cursor_within_document_bounds()
	if view.cursor.pos.y == 0 { return }
	if view.buffer.lines.len == 0 { return }

	for i := view.cursor.pos.y; i > 0; i-- {
		if i == view.cursor.pos.y { continue }
		if view.buffer.lines[i].len == 0 { view.move_cursor_up(view.cursor.pos.y - i); break }
	}
}

fn (mut view View) jump_cursor_down_to_next_blank_line() {
	view.clamp_cursor_within_document_bounds()
	if view.buffer.lines.len == 0 { return }
	if view.cursor.pos.y == view.buffer.lines.len { return }

	for i := view.cursor.pos.y; i < view.buffer.lines.len; i++ {
		if i == view.cursor.pos.y { continue }
		if view.buffer.lines[i].len == 0 { view.move_cursor_down(i - view.cursor.pos.y); break }
	}
}

fn (mut view View) left_square_bracket() {
	view.right_bracket_press_count = 0
	view.left_bracket_press_count += 1

	if view.left_bracket_press_count >= 2 {
		view.move_cursor_up(view.cursor.pos.y);
		view.left_bracket_press_count = 0
	}
}

fn (mut view View) right_square_bracket() {
	view.left_bracket_press_count = 0
	view.right_bracket_press_count += 1

	if view.right_bracket_press_count >= 2 {
		view.move_cursor_down(view.buffer.lines.len - view.cursor.pos.y)
		view.right_bracket_press_count = 0
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

