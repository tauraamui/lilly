// Copyright 2023 The Lilly Editor contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

module main

import os
import term.ui as tui
import log
import datatypes
import strconv
import regex
import lib.clipboard
import arrays

struct Cursor {
mut:
	pos             Pos
	selection_start Pos
}

fn (cursor Cursor) line_is_within_selection(line_y int) bool {
	start := if cursor.selection_start.y < cursor.pos.y { cursor.selection_start.y } else { cursor.pos.y }
	end   := if cursor.pos.y > cursor.selection_start.y { cursor.pos.y } else { cursor.selection_start.y }

	return line_y >= start && line_y <= end
}

fn (cursor Cursor) selection_start_y() int {
	return if cursor.selection_start.y < cursor.pos.y { cursor.selection_start.y } else { cursor.pos.y }
}

fn (cursor Cursor) selection_end_y() int {
	return if cursor.pos.y > cursor.selection_start.y { cursor.pos.y } else { cursor.selection_start.y }
}

fn (cursor Cursor) selection_active() bool { return cursor.selection_start.x >= 0 && cursor.selection_start.y >= 0 }

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
	status_cyan             = Color { 138, 222, 237 }
	status_purple           = Color { 130, 144, 250 }

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

struct View {
mut:
	log                       &log.Log
	path                      string
	config                    Config
	mode                      Mode
	buffer                    Buffer
	cursor                    Cursor
	cmd_buf                   CmdBuffer
	search                    Search
	repeat_amount             string
	x                         int
	width                     int
	height                    int
	from                      int
	to                        int
	show_whitespace           bool
	left_bracket_press_count  int
	right_bracket_press_count int
	syntaxes                  []Syntax
	current_syntax_idx        int
	is_multiline_comment      bool
	d_count                   int
	clipboard                 clipboard.Clipboard
}

struct FindCursor {
mut:
	line             int
	line_match_index int
	match_index      int
}

struct Match {
	start  int
	end    int
	line   int
}

struct Search {
mut:
	to_find      string
	cursor_x     int
	finds        map[int][]int
	current_find FindCursor
	total_finds  int
}

fn (mut search Search) get_line_matches(line_num int) []Match {
	mut matches := []Match{}
	if !(line_num in search.finds.keys()) { return matches }
	line_finds := search.finds[line_num]
	if line_finds.len % 2 != 0 { return matches }

	num_of_finds_on_line := search.finds[line_num].len
	for i in 0..num_of_finds_on_line {
		if i + 1 == num_of_finds_on_line { continue } // could break here obvs, but I like the idea of the loop terminating itself next time around
		matches << Match{ line: line_num, start: search.finds[line_num][i], end: search.finds[line_num][i+1] }
	}
	return matches
}

fn (mut search Search) draw(mut ctx tui.Context, draw_cursor bool) {
	ctx.draw_text(1, ctx.window_height, search.to_find)
	ctx.set_bg_color(r: 230, g: 230, b: 230)
	ctx.draw_point(search.cursor_x+1, ctx.window_height)
	ctx.reset_bg_color()
}

fn (mut search Search) prepare_for_input() {
	search.to_find = "/"
	search.cursor_x = 1
}

fn (mut search Search) put_char(c string) {
	first := search.to_find[..search.cursor_x]
	last  := search.to_find[search.cursor_x..]
	search.to_find = "${first}${c}${last}"
	search.cursor_x += 1
}

fn (mut search Search) left() {
	search.cursor_x -= 1
	if search.cursor_x <= 1 { search.cursor_x = 1 }
}

fn (mut search Search) right() {
	search.cursor_x += 1
	if search.cursor_x > search.to_find.len { search.cursor_x = search.to_find.len }
}

fn (mut search Search) backspace() {
	if search.cursor_x == 1 { return }
	first := search.to_find[..search.cursor_x-1]
	last  := search.to_find[search.cursor_x..]
	search.to_find = "${first}${last}"
	search.cursor_x -= 1
	if search.cursor_x < 1 { search.cursor_x = 1 }
}

fn (mut search Search) find(lines []string) {
	search.current_find = FindCursor{}
	search.total_finds = 0
	mut finds := map[int][]int{}
	mut re := regex.regex_opt(search.to_find.replace_once("/", "")) or { return }
	for i, line in lines {
		found := re.find_all(line)
		if found.len == 0 { continue }
		search.total_finds += found.len / 2
		finds[i] = found
	}
	search.finds = finds.move()
}

fn (mut search Search) next_find_pos() ?Match {
	if search.finds.len == 0 { return none }

	line_number := search.finds.keys()[search.current_find.line]
	line_matches := search.finds[line_number]
	start := line_matches[search.current_find.line_match_index]
	end   := line_matches[search.current_find.line_match_index + 1]

	search.current_find.line_match_index += 2
	search.current_find.match_index += 1
	if search.current_find.match_index > search.total_finds { search.current_find.match_index = 1 }
	if search.current_find.line_match_index + 1 >= line_matches.len {
		search.current_find.line_match_index = 0
		search.current_find.line += 1
		if search.current_find.line >= search.finds.keys().len {
			search.current_find.line = 0
		}
	}

	return Match{ start, end, line_number }
}

fn (mut search Search) clear() {
	search.to_find = ""
	search.cursor_x = 0
	search.finds.clear()
	search.current_find = FindCursor{}
}

struct Find {
mut:
	start int
	end   int
}

struct Buffer {
mut:
	lines []string
}

enum CmdCode as u8 {
	blank
	successful
	unsuccessful
	unrecognised
	disabled
}

fn (code CmdCode) color() Color {
	return match code {
		.blank        { Color{ 230, 230, 230 } }
		.successful   { Color{ 100, 230, 110 } }
		.unsuccessful { Color{ 230, 110, 100 } }
		.unrecognised { Color{ 230, 110, 100 } }
		.disabled     { Color{ 150, 150, 150 } }
	}
}

fn (code CmdCode) str() string {
	return match code {
		.blank        { "" }
		.successful   { "__ command completed successfully" }
		.unsuccessful { "__ command was unsuccessful" }
		.unrecognised { "unrecognised command __" }
		.disabled     { "__ command is disabled" }
	}
}

struct CmdBuffer {
mut:
	line        string
	code        CmdCode
	err_msg     string
	cursor_x    int
	cursor_y    int
	cmd_history datatypes.Queue[string]
}

fn (mut cmd_buf CmdBuffer) draw(mut ctx tui.Context, draw_cursor bool) {
	defer { ctx.reset_bg_color() }
	if cmd_buf.code != .blank {
		color := cmd_buf.code.color()
		ctx.set_color(r: color.r, g: color.g, b: color.b)
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
	cmd_buf.clear_err()
	cmd_buf.line = ":"
	cmd_buf.cursor_x = 1
}

fn (mut cmd_buf CmdBuffer) exec(mut view View) {
	match view.cmd_buf.line {
		":q" { exit(0); cmd_buf.code = .successful }
		":toggle whitespace" {
			// view.show_whitespace = !view.show_whitespace
			cmd_buf.code = .disabled
		}
		":toggle relative line numbers" {
			view.config.relative_line_numbers = !view.config.relative_line_numbers
			cmd_buf.code = .successful
		}
		":toggle rln" {
			view.config.relative_line_numbers = !view.config.relative_line_numbers
			cmd_buf.code = .successful
		}
		":w" {
			cmd_buf.code = .successful
			view.save_file() or { cmd_buf.code = .unsuccessful }
		}
		"" { return }
		else {
			jump_pos, parse_successful := try_to_parse_to_jump_to_line_num(view.cmd_buf.line)
			if !parse_successful { cmd_buf.code = .unrecognised } else {
				view.jump_cursor_to(jump_pos-1)
				cmd_buf.code = .successful
			}
		}
	}

	if cmd_buf.code == .successful {
		cmd_buf.cmd_history.push(cmd_buf.line)
	}
	cmd_buf.set_error(cmd_buf.code.str().replace("__", cmd_buf.line))
}

fn try_to_parse_to_jump_to_line_num(cmd_value string) (int, bool) {
	line_to_jump_to := strconv.atoi(cmd_value.replace(":", "")) or { return 0, false }
	return line_to_jump_to, true
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

fn (mut cmd_buf CmdBuffer) clear_err() {
	cmd_buf.err_msg = ""
	cmd_buf.code = .blank
}

fn (app &App) new_view(_clipboard clipboard.Clipboard) View {
	mut res := View{ log: app.log, mode: .normal, show_whitespace: false, clipboard: _clipboard }
	res.load_syntaxes()
	res.load_config()
	res.set_current_syntax_idx(".v")
	res.cursor.selection_start = Pos{ -1, -1 }
	return res
}

fn (mut view View) open_file(path string) {
	view.path = path
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

	cursor_line := view.buffer.lines[view.cursor.pos.y]
	mut offset := 0
	mut scanto := view.cursor.pos.x
	if scanto > cursor_line.runes().len { scanto = cursor_line.runes().len }

	for c in cursor_line.runes()[..scanto] {
		match c {
			`\t` { offset += 4 }
			else { offset += 1 }
		}
	}

	mut cursor_screen_space_y := view.cursor.pos.y - view.from
	if cursor_screen_space_y > view.code_view_height() - 1 { cursor_screen_space_y = view.code_view_height() - 1 }

	draw_status_line(mut ctx,
		Status{
			view.mode, view.cursor.pos.x,
			view.cursor.pos.y, os.base(view.path)
			SearchSelection{
				active: view.mode == .search,
				total: view.search.total_finds,
				current: view.search.current_find.match_index
			}
		}
	)
	view.cmd_buf.draw(mut ctx, view.mode == .command)
	if view.mode == .search { view.search.draw(mut ctx, view.mode == .search) }

	ctx.draw_text(ctx.window_width-view.repeat_amount.len, ctx.window_height, view.repeat_amount)
	if view.mode == .insert {
		set_cursor_to_vertical_bar(mut ctx)
	} else { set_cursor_to_block(mut ctx) }
	if view.d_count == 1 { set_cursor_to_underline(mut ctx) }
	ctx.set_cursor_position(view.x+1+offset, cursor_screen_space_y+1)
}

fn (mut view View) draw_document(mut ctx tui.Context) {
	mut to := view.from + view.code_view_height()
	if to > view.buffer.lines.len { to = view.buffer.lines.len }
	view.to = to
	ctx.set_bg_color(r: 53, g: 53, b: 53)

	mut cursor_screen_space_y := view.cursor.pos.y - view.from
	// draw cursor line
	if view.mode != .visual {
		if cursor_screen_space_y > view.code_view_height() - 1 { cursor_screen_space_y = view.code_view_height() - 1 }
		ctx.draw_rect(view.x+1, cursor_screen_space_y+1, ctx.window_width, cursor_screen_space_y+1)
	}

	color := view.config.selection_highlight_color
	mut within_selection := false
	// draw document text
	for y, line in view.buffer.lines[view.from..to] {
		ctx.reset_bg_color()
		ctx.reset_color()

		view.draw_text_line_number(mut ctx, y)

		document_space_y := view.from + y
		match view.mode {
			.visual {
				within_selection = view.cursor.line_is_within_selection(document_space_y)
				if within_selection { ctx.set_bg_color(r: color.r, g: color.g, b: color.b) }
			}
			else {
				within_selection = false
				if y == cursor_screen_space_y {
					ctx.set_bg_color(r: 53, g: 53, b: 53)
				}
			}
		}

		search_matches := view.search.get_line_matches(document_space_y)
		if search_matches.len > 0 { ctx.set_bg_color(r: 53, g: 100, b: 230) }
		view.draw_text_line(mut ctx, y, line, within_selection)
	}
}

enum SegmentKind {
	a_string = 1
	a_comment = 2
	a_key = 3
	a_lit = 4
}

struct LineSegment {
	start int
	end   int
	typ   SegmentKind
}

fn (mut view View) draw_text_line(mut ctx tui.Context, y int, line string, within_selection bool) {
	mut linex := line.replace("\t", " ".repeat(4))
	mut max_width := view.width
	if max_width > linex.runes().len { max_width = linex.runes().len }

	linex = linex[..max_width]

	segments, is_multiline_comment := resolve_line_segments(view.syntaxes[view.current_syntax_idx] or { Syntax{} }, linex, view.is_multiline_comment)
	view.is_multiline_comment = is_multiline_comment

	/*
	if view.is_multiline_comment {
		ctx.set_color(r: 130, g: 130, b: 130)
		ctx.draw_text(view.x+1, y+1, linex)
		return
	}
	*/

	if segments.len == 0 || within_selection {
		ctx.draw_text(view.x+1, y+1, linex)
		return
	}

	mut pos := 0
	for i, segment in segments {
		// render text before next segment
		if segment.start > pos {
			s := linex[pos..segment.start]
			ctx.draw_text(view.x+1+pos, y+1, s)
		}

		typ := segment.typ
		color := match typ {
			.a_key { Color{ 255, 126, 182 } }
			.a_lit { Color{ 87, 215, 217 } }
			.a_string { Color{ 87, 215, 217 } }
			.a_comment { Color{ 130, 130, 130 } }
		}
		s := linex[segment.start..segment.end]
		ctx.set_color(r: color.r, g: color.g, b: color.b)
		ctx.draw_text(view.x+1+segment.start, y+1, s)
		ctx.reset_color()
		pos = segment.end
		if i == segments.len - 1 && segment.end < linex.len {
			final := linex[segment.end..linex.len]
			ctx.draw_text(view.x+1+pos, y+1, final)
		}
	}
}

fn resolve_line_segments(syntax Syntax, line string, is_multiline_comment bool) ([]LineSegment, bool) {
	mut segments := []LineSegment{}
	mut is_multiline_commentx := is_multiline_comment
	line_runes := line.runes()
	for i := 0; i < line_runes.len; i++ {
		start := i
		// '//' comment
		if i > 0 && line_runes[i - 1] == `/` && line_runes[i] == `/` {
			segments << LineSegment{ start - 1, line_runes.len, .a_comment }
			break
		}

		// '#' comment
		if line_runes[i] == `#` {
			segments << LineSegment{ start, line_runes.len, .a_comment }
			break
		}

		// /* comment
		// (unless it's /* line_runes */ which is a single line_runes)
		if i > 0 && line_runes[i - 1] == `/` && line_runes[i] == `*` && !(line_runes[line_runes.len - 2] == `*`
			&& line_runes[line_runes.len - 1] == `/`) {
			// all after /* is  a comment
			segments << LineSegment{ start, line.len, .a_comment }
			is_multiline_commentx = true
			break
		}
		// end of /* */
		if i > 0 && line_runes[i - 1] == `*` && line_runes[i] == `/` {
			// all before */ is still a comment
			segments << LineSegment{ 0, start + 1, .a_comment }
			is_multiline_commentx = false
			break
		}

		// string
		if line_runes[i] == `'` {
			i++
			for i < line_runes.len - 1 && line_runes[i] != `'` {
				i++
			}
			if i >= line_runes.len {
				i = line_runes.len - 1
			}
			segments << LineSegment{ start, i + 1, .a_string }
		}

		if line_runes[i] == `"` {
			i++
			for i < line_runes.len - 1 && line_runes[i] != `"` {
				i++
			}
			if i >= line_runes.len {
				i = line_runes.len - 1
			}
			segments << LineSegment{ start, i + 1, .a_string }
		}

		if line_runes[i] == `\`` {
			i++
			for i < line_runes.len - 1 && line_runes[i] != `\`` {
				i++
			}
			if i >= line_runes.len {
				i = line_runes.len - 1
			}
			segments << LineSegment{ start, i + 1, .a_string }
		}

		// key
		for i < line.len && is_alpha_underscore(int(line[i])) {
			i++
		}
		word := line[start..i]
		if word in syntax.literals {
			segments << LineSegment{ start, i, .a_lit }
		} else if word in syntax.keywords {
			segments << LineSegment{ start, i, .a_key }
		}
	}
	return segments, is_multiline_commentx
}

fn (mut view View) draw_text_line_number(mut ctx tui.Context, y int) {
	cursor_screenspace_y := view.cursor.pos.y - view.from
	ctx.set_color(r: 117, g: 118, b: 120)

	mut line_num_str := "${view.from+y+1}"
	if view.config.relative_line_numbers {
		if y < cursor_screenspace_y {
			line_num_str = "${cursor_screenspace_y - y}"
		} else if cursor_screenspace_y == y {
			line_num_str = "${view.from+y+1}"
		} else if y > cursor_screenspace_y {
			line_num_str = "${y - cursor_screenspace_y}"
		}
	}
	ctx.draw_text(view.x - line_num_str.runes().len, y+1, line_num_str)
	ctx.reset_color()
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

// 0 - Default
// 1 - Block (blinking)
// 2 - Block (steady)
// 3 - Underline (blinking)
// 4 - Underline (steady)
// 5 - Bar (blinking)
// 6 - Bar (steady)
fn set_cursor_to_block(mut ctx tui.Context) {
	ctx.write("\x1b[0 q")
}

fn set_cursor_to_underline(mut ctx tui.Context) {
	ctx.write("\x1b[4 q")
}

fn set_cursor_to_vertical_bar(mut ctx tui.Context) {
	ctx.write("\x1b[6 q")
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
				.h     { view.h() }
				.l     { view.l() }
				.j     { view.j() }
				.k     { view.k() }
				.i     { view.i() }
				.v     { if e.modifiers == .shift { view.v() } }
				.e     { view.e() }
				.w     { view.w() }
				.b     { view.b() }
				.o     { view.o() }
				.a     { if e.modifiers == .shift { view.shift_a() } else { view.a() } }
				.p     { view.p() }
				.up    { view.k() }
				.right { view.l() }
				.down  { view.j() }
				.left  { view.h() }
				.d { if e.modifiers == .ctrl { view.ctrl_d() } else { view.d() } }
				.u { if e.modifiers == .ctrl { view.ctrl_u() } }
				.caret { view.hat() }
				.dollar { view.dollar() }
				.left_curly_bracket { view.jump_cursor_up_to_next_blank_line() }
				.right_curly_bracket { view.jump_cursor_down_to_next_blank_line() }
				.colon { view.cmd() }
				.left_square_bracket { view.left_square_bracket() }
				.right_square_bracket { view.right_square_bracket() }
				.slash { view.search() }
				.escape { view.escape() }
				.enter {
					// TODO(tauraamui) -> what even is this, remove??
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
		.visual {
			match e.code {
				.escape    { view.escape() }
				.h         { view.h() }
				.l         { view.l() }
				.j         { view.j() }
				.k         { view.k() }
				.up        { view.k() }
				.right     { view.l() }
				.down      { view.j() }
				.left      { view.h() }
				.less_than { view.visual_unindent() }
				.greater_than { view.visual_indent() }
				.d { if e.modifiers == .ctrl { view.ctrl_d() } else { view.visual_d(true) } }
				.p { view.visual_p() }
				.u { if e.modifiers == .ctrl { view.ctrl_u() } }
				.caret { view.hat() }
				.dollar { view.dollar() }
				.left_curly_bracket { view.jump_cursor_up_to_next_blank_line() }
				.right_curly_bracket { view.jump_cursor_down_to_next_blank_line() }
				.y { view.visual_y() }
				else {}
			}
		}
		.command {
			match e.code {
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
		.search {
			match e.code {
				.escape { view.escape() }
				.space { view.search.put_char(" ") }
				48...57, 97...122 { // 0-9a-zA-Z
					view.search.put_char(e.ascii.ascii_str())
				}
				.left { view.search.left() }
				.right { view.search.right() }
				.up {}
				.down {}
				.backspace { view.search.backspace() }
				.enter { view.search.find(view.buffer.lines) }
				.tab { pos := view.search.next_find_pos() or { return }; view.jump_cursor_to(pos.line) }
				else {
					view.search.put_char(e.ascii.ascii_str())
				}
			}
		}
		.insert {
			match e.code {
				.escape { view.escape() }
				.enter { view.enter() }
				.backspace { view.backspace() }
				.up {}
				.down {}
				.left { view.left() }
				.right { view.right() }
				.tab { view.insert_tab() }
				.single_quote { view.insert_text("\'\'"); view.cursor.pos.x -= 1; view.clamp_cursor_x_pos() }
				.double_quote { view.insert_text("\"\""); view.cursor.pos.x -= 1; view.clamp_cursor_x_pos() }
				.left_paren { view.insert_text('()'); view.cursor.pos.x -= 1; view.clamp_cursor_x_pos() }
				.left_curly_bracket { view.insert_text('{}'); view.cursor.pos.x -= 1; view.clamp_cursor_x_pos() }
				.left_square_bracket { view.insert_text('[]'); view.cursor.pos.x -= 1; view.clamp_cursor_x_pos() }
				48...57, 97...122 { // 0-9a-zA-Z
					view.insert_text(e.ascii.ascii_str())
				}
				else {
					buf := [5]u8{}
					s := unsafe { utf32_to_str_no_malloc(u32(e.code), &buf[0]) }
					view.insert_text(s)
				}
			}
		}
		.pending_delete {
			match e.code {
				.escape { view.escape() }
				.d { view.d() }
				else {}
			}
		}
	}
}

fn (mut view View) insert_tab() {
	if view.config.insert_tabs_not_spaces {
		view.insert_text("\t")
		return
	}
	view.insert_text(" ".repeat(4))
}

fn (mut view View) visual_indent() {
	mut start := view.cursor.selection_start_y()
	mut end := view.cursor.selection_end_y()

    prefix := if view.config.insert_tabs_not_spaces { "\t" } else { " ".repeat(4) }

    for i := start; i < end; i++ {
        view.buffer.lines[i] = "${prefix}${view.buffer.lines[i]}"
    }
}

fn (mut view View) visual_unindent() {
}

fn (mut view View) save_file()! {
	if view.path == '' {
		return
	}
	path := view.path
	mut file := os.create(path)!
	for line in view.buffer.lines {
		file.writeln(line.trim_right(' \t'))!
	}
	file.close()
}


fn (mut view View) char_insert(s string) {
	if int(s[0]) < 32 {
		return
	}
	view.insert_text(s)
}

fn (mut view View) insert_text(s string) {
	defer { view.clamp_cursor_x_pos() }
	y := view.cursor.pos.y
	line := view.buffer.lines[y]
	if line.len == 0 {
		view.buffer.lines[y] = '${s}'
	} else {
		if view.cursor.pos.x > line.len {
			view.cursor.pos.x = line.len
		}
		uline := line.runes()
		if view.cursor.pos.x > uline.len {
			return
		}
		left := uline[..view.cursor.pos.x].string()
		right := uline[view.cursor.pos.x..uline.len].string()
		// insert char in the middle
		view.buffer.lines[y] = '${left}${s}${right}'
	}
	view.cursor.pos.x += s.runes().len
}

fn (mut view View) escape() {
	// TODO(tauraamui) -> completely re-write this method
	defer {
		if view.cursor.selection_active() {
			view.cursor.pos.y = view.cursor.selection_start_y()
		}
		view.cursor.selection_start = Pos{ -1, -1 }
		view.clamp_cursor_within_document_bounds()
		view.scroll_from_and_to()
	}
	view.mode = .normal
	view.repeat_amount = ""
	view.cursor.pos.x -= 1
	view.clamp_cursor_x_pos()
	view.cmd_buf.clear()
	view.search.clear()
	view.d_count = 0

	// if current line only contains whitespace prefix clear the line
	line := view.buffer.lines[view.cursor.pos.y]
	whitespace_prefix := resolve_whitespace_prefix(line)
	if whitespace_prefix.len == line.len {
		view.buffer.lines[view.cursor.pos.y] = ""
	}
}

fn (mut view View) jump_cursor_to(position int) {
	defer {
		view.clamp_cursor_within_document_bounds()
		view.clamp_cursor_x_pos()
	}
	view.cursor.pos.y = position
	view.clamp_cursor_within_document_bounds()
	view.scroll_from_and_to()
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
	view.clamp_cursor_within_document_bounds()
	line_len := view.buffer.lines[view.cursor.pos.y].runes().len
	if line_len == 0 { view.cursor.pos.x = 0; return }
	if view.mode == .insert {
		if view.cursor.pos.x > line_len { view.cursor.pos.x = line_len }
	} else {
		if view.cursor.pos.x > line_len - 1 { view.cursor.pos.x = line_len - 1 }
	}
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

fn (mut view View) search() {
	view.mode = .search
	view.search.prepare_for_input()
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
	view.clamp_cursor_x_pos()
}

fn (mut view View) v() {
	view.mode = .visual
	view.cursor.selection_start = view.cursor.pos
}

fn (mut view View) visual_y() {
	start := view.cursor.selection_start_y()
	mut end   := view.cursor.selection_end_y()
	if end+1 >= view.buffer.lines.len { end = view.buffer.lines.len-1 }
	view.copy_lines_into_clipboard(start, end)
	view.escape()
}

fn (mut view View) copy_lines_into_clipboard(start int, end int) {
	view.clipboard.copy(arrays.join_to_string(view.buffer.lines[start..end+1].clone(), "\n", fn (s string) string { return s }))
}

fn (mut view View) read_lines_from_clipboard() []string {
	return view.clipboard.paste()
}

fn (mut view View) visual_d(overwrite_y_lines bool) {
	defer { view.clamp_cursor_within_document_bounds() }
	mut start := view.cursor.selection_start_y()
	mut end := view.cursor.selection_end_y()

	view.copy_lines_into_clipboard(start, end)
	before := view.buffer.lines[..start]
	after := view.buffer.lines[end+1..]

	view.buffer.lines = before
	view.buffer.lines << after
	view.cursor.pos.y = start
	view.escape()
}

fn (mut view View) w() {
	line := view.buffer.lines[view.cursor.pos.y]
	amount := calc_w_move_amount(view.cursor.pos, line)
	if amount == 0 { view.move_cursor_down(1); view.cursor.pos.x = 0; return }
	view.cursor.pos.x += calc_w_move_amount(view.cursor.pos, line)
	view.clamp_cursor_x_pos()
}

fn (mut view View) e() {
	line := view.buffer.lines[view.cursor.pos.y]
	amount := calc_e_move_amount(view.cursor.pos, line)
	if amount == 0 { view.move_cursor_down(1); view.cursor.pos.x = 0; return }
	view.cursor.pos.x += amount
	view.clamp_cursor_x_pos()
}

fn (mut view View) b() {
	defer { view.clamp_cursor_x_pos() }
	line := view.buffer.lines[view.cursor.pos.y]
	amount := calc_b_move_amount(view.cursor.pos, line)
	if amount == 0 && view.cursor.pos.y > 0 {
		view.move_cursor_up(1)
		view.cursor.pos.x = view.buffer.lines[view.cursor.pos.y].runes().len - 1
		return
	}
	view.cursor.pos.x -= amount
}

fn (mut view View) ctrl_d() {
	ten_percent_of_total_lines := f32(view.buffer.lines.len) * .05
	view.move_cursor_down(int(ten_percent_of_total_lines))
	view.clamp_cursor_x_pos()
}

fn (mut view View) ctrl_u() {
	ten_percent_of_total_lines := f32(view.buffer.lines.len) * .05
	view.move_cursor_up(int(ten_percent_of_total_lines))
	view.clamp_cursor_x_pos()
}

fn (mut view View) hat() {
	view.cursor.pos.x = 0
}

fn (mut view View) dollar() {
    defer { view.clamp_cursor_x_pos() }
	line := view.buffer.lines[view.cursor.pos.y]
	view.cursor.pos.x = line.runes().len - 1
}

fn (mut view View) d() {
	view.d_count += 1
	if view.d_count == 1 { view.mode = .pending_delete }
	if view.d_count == 2 {
		index := if view.cursor.pos.y == view.buffer.lines.len { view.cursor.pos.y - 1 } else { view.cursor.pos.y }
		view.copy_lines_into_clipboard(index, index)
		view.buffer.lines.delete(index)
		view.d_count = 0
		view.clamp_cursor_within_document_bounds()
		view.mode = .normal
	}
}

fn (mut view View) o() {
	defer { view.move_cursor_down(1) }
	view.mode = .insert
	y := view.cursor.pos.y
	whitespace_prefix := resolve_whitespace_prefix(view.buffer.lines[y])
	defer { view.cursor.pos.x = whitespace_prefix.len }
	if y >= view.buffer.lines.len { view.buffer.lines << "${whitespace_prefix}"; return }
	view.buffer.lines.insert(y+1, "${whitespace_prefix}")
}

fn (mut view View) a() {
	view.mode = .insert
	view.cursor.pos.x += 1
}

fn (mut view View) shift_a() {
	view.dollar()
	view.a()
}

fn (mut view View) p() {
	copied_lines := view.read_lines_from_clipboard()
	view.buffer.lines.insert(view.cursor.pos.y+1, copied_lines)
	view.move_cursor_down(copied_lines.len)
}

fn (mut view View) visual_p() {
	defer { view.clamp_cursor_within_document_bounds() }
	mut start := view.cursor.selection_start_y()
	mut end := view.cursor.selection_end_y()

	before := view.buffer.lines[..start]
	after := view.buffer.lines[end+1..]

	copied_lines := view.read_lines_from_clipboard()

	view.buffer.lines = before
	view.buffer.lines << after
	view.cursor.pos.y = start
	view.buffer.lines.insert(view.cursor.pos.y, copied_lines)
	view.move_cursor_down(copied_lines.len)
	view.escape()
}

fn (mut view View) enter() {
	y := view.cursor.pos.y
	mut whitespace_prefix := resolve_whitespace_prefix(view.buffer.lines[y])
	if whitespace_prefix.len == view.buffer.lines[y].len { // if the current line only has whitespace on it
		view.buffer.lines[y] = ""
		whitespace_prefix = ""
		view.cursor.pos.x = 0
	}
	after_cursor := view.buffer.lines[y][view.cursor.pos.x..]
	view.buffer.lines[y] = view.buffer.lines[y][..view.cursor.pos.x]
	view.buffer.lines.insert(y + 1, "${whitespace_prefix}${after_cursor}")
	view.move_cursor_down(1)
	view.cursor.pos.x = whitespace_prefix.len
	view.clamp_cursor_x_pos()
}

fn resolve_whitespace_prefix(line string) string {
	mut prefix_ends := 0
	for i, c in line {
		if !is_whitespace(c) { prefix_ends = i; return line[..prefix_ends] }
	}
	return line
}

fn (mut view View) backspace() {
	y := view.cursor.pos.y

	if view.cursor.pos.x == 0 && y == 0 { return }

	mut line := view.buffer.lines[y]

	if view.cursor.pos.x == 0 {
		previous_line := view.buffer.lines[y - 1]
		view.buffer.lines[y - 1] = "${previous_line}${view.buffer.lines[y]}"
		view.buffer.lines.delete(y)
		view.move_cursor_up(1)
		view.cursor.pos.x = previous_line.len

		if view.cursor.pos.y < 0 { view.cursor.pos.y = 0 }
		return
	}

	if view.cursor.pos.x == line.len {
		view.buffer.lines[y] = line[..line.len - 1]
		view.cursor.pos.x = view.buffer.lines[y].len
		return
	}

	before := line[..view.cursor.pos.x-1]
	after := line[view.cursor.pos.x..]
	view.buffer.lines[y] = "${before}${after}"
	view.cursor.pos.x -= 1
	if view.cursor.pos.x < 0 { view.cursor.pos.x = 0 }
}

fn (mut view View) left() {
	view.cursor.pos.x -= 1
	if view.cursor.pos.x < 0 { view.cursor.pos.x = 0 }
}

fn (mut view View) right() {
	view.cursor.pos.x += 1
	view.clamp_cursor_x_pos()
}

fn calc_w_move_amount(cursor_pos Pos, line string) int {
	if line.len == 0 { return 0 }
	mut next_whitespace := 0
	for i, c in line.runes()[cursor_pos.x..] {
		if is_whitespace(c) { next_whitespace = i; break }
	}

	mut next_alpha := 0
	for i, c in line.runes()[cursor_pos.x+next_whitespace..] {
		if !is_whitespace(c) { next_alpha = i; break }
	}
	return next_whitespace + next_alpha
}

fn calc_e_move_amount(cursor_pos Pos, line string) int {
    if line.len == 0 { return 0 }

	if is_whitespace(line[cursor_pos.x]) {
		mut word_start_offset := 0
		for i, c in line.runes()[cursor_pos.x..] {
			if !is_whitespace(c) { word_start_offset = i; break }
			if cursor_pos.x + i == line.runes().len - 1 { word_start_offset = i; break }
		}

		mut word_end_offset := 0
		for i, c in line.runes()[cursor_pos.x+word_start_offset..] {
			if is_whitespace(c) { word_end_offset = i - 1; break }
			if cursor_pos.x + word_start_offset + i == line.runes().len - 1 { word_end_offset = i; break }
		}

		return word_start_offset + word_end_offset
	}

	if !is_whitespace(line[cursor_pos.x]) {
		mut word_start_offset := 0
		mut word_end_offset := 0
		for i, c in line.runes()[cursor_pos.x..] {
			if is_whitespace(c) { word_end_offset = i - 1; break }
		}

		// already at end of a word, find the start of next word
		if word_end_offset == 0 {
			for i, c in line.runes()[cursor_pos.x..] {
				if i > 0 && !is_whitespace(c) { word_start_offset = i; break }
			}

			// find the end of this word
			word_end_offset = 0
			for i, c in line.runes()[cursor_pos.x+word_start_offset..] {
				if is_whitespace(c) { word_end_offset = i - 1; break }
				if cursor_pos.x + word_start_offset + i == line.runes().len - 1 { word_end_offset = i; break }
			}

			return word_start_offset + word_end_offset
		}

		return word_end_offset
	}

	return 0
}

fn calc_b_move_amount(cursor_pos Pos, line string) int {
    if line.len == 0 || cursor_pos.x == 0 { return 0 }

	if !is_whitespace(line.runes()[cursor_pos.x]) {
		mut word_start_offset := 0
		for i := cursor_pos.x - 1; i >= 0; i-- {
			if is_whitespace(line.runes()[i]) { break }
			word_start_offset += 1
		}

		// we're already at the start of this word, find the end of the previous word
		if word_start_offset == 0 {
			mut word_end_offset := 0
			for i := cursor_pos.x - 1; i >= 0; i-- {
				if !is_whitespace(line.runes()[i]) { break }
				word_end_offset += 1
			}

			// first start of this word
			word_start_offset = 0
			for i := cursor_pos.x - 1 - word_end_offset; i >= 0; i-- {
				if is_whitespace(line.runes()[i]) { break }
				word_start_offset += 1
			}

			return word_end_offset + word_start_offset
		}

		return word_start_offset
	}

	return 0
}

fn (mut view View) jump_cursor_up_to_next_blank_line() {
	view.clamp_cursor_within_document_bounds()
	if view.cursor.pos.y == 0 { return }
	if view.buffer.lines.len == 0 { return }

	for i := view.cursor.pos.y; i > 0; i-- {
		if i == view.cursor.pos.y { continue }
		if view.buffer.lines[i].len == 0 { view.move_cursor_up(view.cursor.pos.y - i); return }
	}

	view.move_cursor_up(view.cursor.pos.y)
}

fn (mut view View) jump_cursor_down_to_next_blank_line() {
	view.clamp_cursor_within_document_bounds()
	if view.buffer.lines.len == 0 { return }
	if view.cursor.pos.y == view.buffer.lines.len { return }

	for i := view.cursor.pos.y; i < view.buffer.lines.len; i++ {
		if i == view.cursor.pos.y { continue }
		if view.buffer.lines[i].len == 0 { view.move_cursor_down(i - view.cursor.pos.y); return }
	}

	view.move_cursor_down(view.buffer.lines.len - view.cursor.pos.y)
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

