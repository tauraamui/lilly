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
import strings
import regex
import lib.clipboard
import arrays
import lib.buffer
import lib.workspace
import lib.chords
import lib.draw

struct Cursor {
mut:
	pos                 Pos
	selection_start_pos Pos
}

fn (cursor Cursor) line_is_within_selection(line_y int) bool {
	start := if cursor.selection_start_pos.y < cursor.pos.y {
		cursor.selection_start_pos.y
	} else {
		cursor.pos.y
	}
	end := if cursor.pos.y > cursor.selection_start_pos.y {
		cursor.pos.y
	} else {
		cursor.selection_start_pos.y
	}

	return line_y >= start && line_y <= end
}

fn (cursor Cursor) selection_start() Pos {
	if cursor.selection_start_pos.y == cursor.pos.y {
		if cursor.selection_start_pos.x == cursor.pos.x {
			return cursor.selection_start_pos
		}
		if cursor.selection_start_pos.x < cursor.pos.x {
			return cursor.selection_start_pos
		}
		return cursor.pos
	}
	if cursor.selection_start_pos.y < cursor.pos.y {
		return cursor.selection_start_pos
	} else {
		return cursor.pos
	}
}

fn (cursor Cursor) selection_end() Pos {
	if cursor.pos.y == cursor.selection_start_pos.y {
		if cursor.pos.x == cursor.selection_start_pos.x {
			return cursor.pos
		}
		if cursor.pos.x > cursor.selection_start_pos.x {
			return cursor.pos
		}
		return cursor.selection_start_pos
	}
	if cursor.pos.y > cursor.selection_start_pos.y {
		return cursor.pos
	} else {
		return cursor.selection_start_pos
	}
}

fn (cursor Cursor) selection_active() bool {
	return cursor.selection_start_pos.x >= 0 && cursor.selection_start_pos.y >= 0
}

struct Pos {
mut:
	x int
	y int
}

const block = '█'
const slant_left_flat_bottom = ''
const left_rounded = ''
const slant_left_flat_top = ''
const slant_right_flat_bottom = ''
const right_rounded = ''
const slant_right_flat_top = ''

const status_green = Color{145, 237, 145}
const status_orange = Color{237, 207, 123}
const status_lilac = Color{194, 110, 230}
const status_dark_lilac = Color{154, 119, 209}
const status_cyan = Color{138, 222, 237}
const status_purple = Color{130, 144, 250}

const rune_digits = [`0`, `1`, `2`, `3`, `4`, `5`, `6`, `7`, `8`, `9`]

const zero_width_unicode = [
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

const auto_pairs = {
	'}': '{'
	']': '['
	')': '('
	'"': '"'
	"'": "'"
}

struct ViewLeaderState {
mut:
	mode    Mode
	d_count int
	f_count int
	b_count int
}

fn (mut state ViewLeaderState) reset() {
	state.mode = .normal
	state.d_count = 0
	state.f_count = 0
	state.b_count = 0
}

struct View {
pub:
	file_path string
mut:
	log                       &log.Log
	path                      string
	branch                    string
	config                    workspace.Config
	leader_state              ViewLeaderState
	buffer                    buffer.Buffer
	leader_key                string
	cursor                    Cursor
	cmd_buf                   CmdBuffer
	search                    Search
	chord                     chords.Chord
	x                         int
	width                     int
	height                    int
	from                      int
	to                        int
	show_whitespace           bool
	left_bracket_press_count  int
	right_bracket_press_count int
	syntaxes                  []workspace.Syntax
	current_syntax_idx        int
	is_multiline_comment      bool
	clipboard                 clipboard.Clipboard
}

struct FindCursor {
mut:
	line             int
	line_match_index int
	match_index      int
}

struct Match {
	start int
	end   int
	line  int
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
	if line_num !in search.finds.keys() {
		return matches
	}
	line_finds := search.finds[line_num]
	if line_finds.len % 2 != 0 {
		return matches
	}

	num_of_finds_on_line := search.finds[line_num].len
	for i in 0 .. num_of_finds_on_line {
		if i + 1 == num_of_finds_on_line {
			continue
		}
		// could break here obvs, but I like the idea of the loop terminating itself next time around
		matches << Match{
			line:  line_num
			start: search.finds[line_num][i]
			end:   search.finds[line_num][i + 1]
		}
	}
	return matches
}

fn (mut search Search) draw(mut ctx draw.Contextable, draw_cursor bool) {
	ctx.draw_text(1, ctx.window_height(), search.to_find)
	ctx.set_bg_color(r: 230, g: 230, b: 230)
	ctx.draw_point(search.cursor_x + 1, ctx.window_height())
	ctx.reset_bg_color()
}

fn (mut search Search) prepare_for_input() {
	search.to_find = '/'
	search.cursor_x = 1
}

fn (mut search Search) put_char(c string) {
	first := search.to_find[..search.cursor_x]
	last := search.to_find[search.cursor_x..]
	search.to_find = '${first}${c}${last}'
	search.cursor_x += 1
}

fn (mut search Search) left() {
	search.cursor_x -= 1
	if search.cursor_x <= 1 {
		search.cursor_x = 1
	}
}

fn (mut search Search) right() {
	search.cursor_x += 1
	if search.cursor_x > search.to_find.len {
		search.cursor_x = search.to_find.len
	}
}

fn (mut search Search) backspace() {
	if search.cursor_x == 1 {
		return
	}
	first := search.to_find[..search.cursor_x - 1]
	last := search.to_find[search.cursor_x..]
	search.to_find = '${first}${last}'
	search.cursor_x -= 1
	if search.cursor_x < 1 {
		search.cursor_x = 1
	}
}

fn (mut search Search) find(lines []string) {
	search.current_find = FindCursor{}
	search.total_finds = 0
	mut finds := map[int][]int{}
	mut re := regex.regex_opt(search.to_find.replace_once('/', '')) or { return }
	for i, line in lines {
		found := re.find_all(line)
		if found.len == 0 {
			continue
		}
		search.total_finds += found.len / 2
		finds[i] = found
	}
	search.finds = finds.move()
}

fn (mut search Search) next_find_pos() ?Match {
	if search.finds.len == 0 {
		return none
	}

	line_number := search.finds.keys()[search.current_find.line]
	line_matches := search.finds[line_number]
	start := line_matches[search.current_find.line_match_index]
	end := line_matches[search.current_find.line_match_index + 1]

	search.current_find.line_match_index += 2
	search.current_find.match_index += 1
	if search.current_find.match_index > search.total_finds {
		search.current_find.match_index = 1
	}
	if search.current_find.line_match_index + 1 >= line_matches.len {
		search.current_find.line_match_index = 0
		search.current_find.line += 1
		if search.current_find.line >= search.finds.keys().len {
			search.current_find.line = 0
		}
	}

	return Match{start, end, line_number}
}

fn (mut search Search) clear() {
	search.to_find = ''
	search.cursor_x = 0
	search.finds.clear()
	search.current_find = FindCursor{}
}

struct Find {
mut:
	start int
	end   int
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
		.blank { Color{230, 230, 230} }
		.successful { Color{100, 230, 110} }
		.unsuccessful { Color{230, 110, 100} }
		.unrecognised { Color{230, 110, 100} }
		.disabled { Color{150, 150, 150} }
	}
}

fn (code CmdCode) str() string {
	return match code {
		.blank { '' }
		.successful { '__ command completed successfully' }
		.unsuccessful { '__ command was unsuccessful' }
		.unrecognised { 'unrecognised command __' }
		.disabled { '__ command is disabled' }
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

fn (mut cmd_buf CmdBuffer) draw(mut ctx draw.Contextable, draw_cursor bool) {
	defer { ctx.reset_bg_color() }
	if cmd_buf.code != .blank {
		color := cmd_buf.code.color()
		ctx.set_color(r: color.r, g: color.g, b: color.b)
		ctx.draw_text(1, ctx.window_height(), cmd_buf.err_msg)
		ctx.reset_color()
		return
	}
	ctx.draw_text(1, ctx.window_height(), cmd_buf.line)
	if draw_cursor {
		ctx.set_bg_color(r: 230, g: 230, b: 230)
		ctx.draw_point(cmd_buf.cursor_x + 1, ctx.window_height())
	}
}

fn (mut cmd_buf CmdBuffer) prepare_for_input() {
	cmd_buf.clear_err()
	cmd_buf.line = ':'
	cmd_buf.cursor_x = 1
}

fn (mut cmd_buf CmdBuffer) exec(mut view View, mut root Root) {
	match view.cmd_buf.line {
		':q' {
			root.quit()
			cmd_buf.code = .successful
		}
		':toggle whitespace' {
			// view.show_whitespace = !view.show_whitespace
			cmd_buf.code = .disabled
		}
		':toggle relative line numbers' {
			view.config.relative_line_numbers = !view.config.relative_line_numbers
			cmd_buf.code = .successful
		}
		':toggle rln' {
			view.config.relative_line_numbers = !view.config.relative_line_numbers
			cmd_buf.code = .successful
		}
		':w' {
			cmd_buf.code = .successful
			view.save_file() or { cmd_buf.code = .unsuccessful }
		}
		':wq' {
			cmd_buf.code = .successful
			view.save_file() or { cmd_buf.code = .unsuccessful }
			if cmd_buf.code == .successful {
				root.quit()
			}
		}
		':version' {
			cmd_buf.line = 'lilly version #${gitcommit_hash} -'
			cmd_buf.code = .successful
		}
		'' {
			return
		}
		else {
			jump_pos, parse_successful := try_to_parse_to_jump_to_line_num(view.cmd_buf.line)
			if !parse_successful {
				cmd_buf.code = .unrecognised
			} else {
				view.jump_cursor_to(jump_pos - 1)
				cmd_buf.code = .successful
			}
		}
	}

	if cmd_buf.code == .successful {
		cmd_buf.cmd_history.push(cmd_buf.line)
	}
	cmd_buf.set_error(cmd_buf.code.str().replace('__', cmd_buf.line))
}

fn try_to_parse_to_jump_to_line_num(cmd_value string) (int, bool) {
	line_to_jump_to := strconv.atoi(cmd_value.replace(':', '')) or { return 0, false }
	return line_to_jump_to, true
}

fn (mut cmd_buf CmdBuffer) put_char(c string) {
	first := cmd_buf.line[..cmd_buf.cursor_x]
	last := cmd_buf.line[cmd_buf.cursor_x..]
	cmd_buf.line = '${first}${c}${last}'
	cmd_buf.cursor_x += 1
}

fn (mut cmd_buf CmdBuffer) up() {
	cmd_buf.cursor_y -= 1
	if cmd_buf.cursor_y < 0 {
		cmd_buf.cursor_y = 0
	}
	if cmd_buf.cmd_history.len() > 0 {
		cmd_buf.line = cmd_buf.cmd_history.index(cmd_buf.cursor_y) or { ':' }
		cmd_buf.cursor_x = cmd_buf.line.len
	}
}

fn (mut cmd_buf CmdBuffer) left() {
	cmd_buf.cursor_x -= 1
	if cmd_buf.cursor_x <= 0 {
		cmd_buf.cursor_x = 0
	}
}

fn (mut cmd_buf CmdBuffer) right() {
	cmd_buf.cursor_x += 1
	if cmd_buf.cursor_x > cmd_buf.line.len {
		cmd_buf.cursor_x = cmd_buf.line.len
	}
}

fn (mut cmd_buf CmdBuffer) backspace() {
	if cmd_buf.cursor_x == 0 {
		return
	}
	first := cmd_buf.line[..cmd_buf.cursor_x - 1]
	last := cmd_buf.line[cmd_buf.cursor_x..]
	cmd_buf.line = '${first}${last}'
	cmd_buf.cursor_x -= 1
	if cmd_buf.cursor_x < 0 {
		cmd_buf.cursor_x = 0
	}
}

fn (mut cmd_buf CmdBuffer) set_error(msg string) {
	cmd_buf.line = ''
	cmd_buf.err_msg = msg
}

fn (mut cmd_buf CmdBuffer) clear() {
	cmd_buf.line = ''
	cmd_buf.cursor_x = 0
}

fn (mut cmd_buf CmdBuffer) clear_err() {
	cmd_buf.err_msg = ''
	cmd_buf.code = .blank
}

fn open_view(config workspace.Config, branch string, syntaxes []workspace.Syntax, _clipboard clipboard.Clipboard, mut buff buffer.Buffer) Viewable {
	mut res := View{
		log:             unsafe { nil }
		branch:          branch
		syntaxes:        syntaxes
		file_path:       buff.file_path
		config:          config
		leader_key:      config.leader_key
		leader_state:     ViewLeaderState{ mode: .normal }
		show_whitespace: false
		clipboard:       _clipboard
		buffer:          buff
	}
	res.path = res.buffer.file_path
	res.set_current_syntax_idx(os.file_ext(res.path))
	res.cursor.selection_start_pos = Pos{-1, -1}
	return res
}

fn (mut view View) set_current_syntax_idx(ext string) {
	for i, syntax in view.syntaxes {
		if ext in syntax.extensions {
			view.current_syntax_idx = i
			break
		}
	}
}

/*
fn (app &App) new_view(_clipboard clipboard.Clipboard) Viewable {
	mut res := View{ log: app.log, leader_state: ViewLeaderState{ mode: .normal }, show_whitespace: false, clipboard: _clipboard }
	res.load_syntaxes()
	res.load_config()
	res.set_current_syntax_idx(".v")
	res.cursor.selection_start = Pos{ -1, -1 }
	return res
}
*/

/*
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
*/

interface Viewable {
	file_path string
mut:
	draw(mut draw.Contextable)
	on_key_down(draw.Event, mut Root)
}

@[inline]
fn (mut view View) offset_x_and_width_by_len_of_longest_line_number_str(win_width int, win_height int) {
	view.height = win_height
	view.x = '${view.buffer.lines.len}'.len + 1
	view.width = win_width - view.x
}

// TODO(tauraamui): use this/do something similar for visual mode highlighting
@[inline]
fn (mut view View) calc_cursor_x_offset() int {
	cursor_line := view.buffer.lines[view.cursor.pos.y]
	mut offset := 0
	mut scanto := view.cursor.pos.x
	if scanto > cursor_line.runes().len {
		scanto = cursor_line.runes().len
	}

	for c in cursor_line.runes()[..scanto] {
		match c {
			`\t` { offset += 4 }
			else { offset += 1 }
		}
	}

	return offset
}

@[inline]
fn (mut view View) calc_cursor_y_in_screen_space() int {
	mut cursor_screen_space_y := view.cursor.pos.y - view.from
	if cursor_screen_space_y > view.code_view_height() - 1 {
		cursor_screen_space_y = view.code_view_height() - 1
	}
	return cursor_screen_space_y
}

@[inline]
fn (mut view View) draw_bottom_bar_of_command_or_search(mut ctx draw.Contextable) {
	view.cmd_buf.draw(mut ctx, view.leader_state.mode == .command)
	if view.leader_state.mode == .search {
		view.search.draw(mut ctx, view.leader_state.mode == .search)
	}
	repeat_amount := view.chord.pending_repeat_amount()
	ctx.draw_text(ctx.window_width() - repeat_amount.len, ctx.window_height(), repeat_amount)
}

@[inline]
fn (mut view View) draw_cursor_pointer(mut ctx draw.Contextable) {
	if view.leader_state.mode == .insert {
		set_cursor_to_vertical_bar(mut ctx)
	} else {
		set_cursor_to_block(mut ctx)
	}
	if view.leader_state.d_count == 1 || view.leader_state.mode == .replace {
		set_cursor_to_underline(mut ctx)
	}
	ctx.set_cursor_position(view.x + 1 + view.calc_cursor_x_offset(),
		view.calc_cursor_y_in_screen_space() + 1)
}

fn (mut view View) draw(mut ctx draw.Contextable) {
	view.offset_x_and_width_by_len_of_longest_line_number_str(ctx.window_width(), ctx.window_height())

	view.draw_document(mut ctx)

	draw_status_line(mut ctx, Status{view.leader_state.mode, view.cursor.pos.x, view.cursor.pos.y, os.base(view.path), SearchSelection{
		active:  view.leader_state.mode == .search
		total:   view.search.total_finds
		current: view.search.current_find.match_index
	}, view.branch})

	view.draw_bottom_bar_of_command_or_search(mut ctx)

	view.draw_cursor_pointer(mut ctx)
}

fn (mut view View) update_to() {
	mut to := view.from + view.code_view_height()
	if to > view.buffer.lines.len {
		to = view.buffer.lines.len
	}
	view.to = to
}

fn (mut view View) draw_document(mut ctx draw.Contextable) {
	view.update_to()
	ctx.set_bg_color(r: 53, g: 53, b: 53)

	mut cursor_screen_space_y := view.cursor.pos.y - view.from
	// draw cursor line
	if view.leader_state.mode != .visual_line {
		if cursor_screen_space_y > view.code_view_height() - 1 {
			cursor_screen_space_y = view.code_view_height() - 1
		}
		ctx.draw_rect(view.x + 1, cursor_screen_space_y + 1, ctx.window_width(),
			cursor_screen_space_y + 1)
	}

	for y, line in view.buffer.lines[view.from..view.to] {
		ctx.reset_bg_color()
		ctx.reset_color()

		view.draw_text_line_number(mut ctx, y)

		document_space_y := view.from + y

		mut linex := line.replace('\t', ' '.repeat(4))
		mut max_width := view.width
		visible_len := utf8_str_visible_length(linex)
		if max_width > visible_len {
			max_width = visible_len
		}

		linex = linex.runes()[..max_width].string()
		sel_highlight_color := Color{
			r: view.config.selection_highlight_color.r
			g: view.config.selection_highlight_color.g
			b: view.config.selection_highlight_color.b
		}
		draw_text_line(mut ctx, view.syntaxes[view.current_syntax_idx] or { workspace.Syntax{} },
			view.cursor, view.leader_state.mode, sel_highlight_color, view.x, y, document_space_y,
			cursor_screen_space_y, linex, line)
	}
}

fn draw_text_line(mut ctx draw.Contextable,
	syntax workspace.Syntax,
	cursor Cursor,
	current_mode Mode,
	selection_highlight_color Color,
	screen_space_x int, screen_space_y int, document_space_y int,
	cursor_screen_space_y int,
	line string,
	original_line string) {
	match current_mode {
		.visual_line {
			within_selection := cursor.line_is_within_selection(document_space_y)
			if within_selection {
				ctx.set_bg_color(
					r: selection_highlight_color.r
					g: selection_highlight_color.g
					b: selection_highlight_color.b
				)
			}
			draw_text_line_as_segments(mut ctx, syntax, screen_space_x, screen_space_y,
				document_space_y, line)
			// ctx.draw_text(screen_space_x+1, screen_space_y+1, line)
			return
		}
		.visual {
			if cursor.line_is_within_selection(document_space_y) {
				draw_text_line_within_visual_selection(mut ctx, syntax, cursor, selection_highlight_color,
					screen_space_x, screen_space_y, document_space_y, cursor_screen_space_y,
					line, original_line)
				return
			}
			draw_text_line_as_segments(mut ctx, syntax, screen_space_x, screen_space_y,
				document_space_y, line)
			// ctx.draw_text(screen_space_x+1, screen_space_y+1, line)
		}
		else {
			if screen_space_y == cursor_screen_space_y {
				ctx.set_bg_color(r: 53, g: 53, b: 53)
			}
			draw_text_line_as_segments(mut ctx, syntax, screen_space_x, screen_space_y,
				document_space_y, line)
			// ctx.draw_text(screen_space_x+1, screen_space_y+1, line)
			return
		}
	}
}

fn draw_text_line_within_visual_selection(mut ctx draw.Contextable,
	syntax workspace.Syntax,
	cursor Cursor,
	selection_highlight_color Color,
	screen_space_x int, screen_space_y int, document_space_y int,
	cursor_screen_space_y int,
	line string,
	original_line string) {
	line_runes := line.runes()
	if line_runes.len == 0 {
		return
	}
	// NOTE(tauraamui): don't think this can happen from upstream but safe to check

	selection_start := cursor.selection_start()
	selection_end := cursor.selection_end()

	if document_space_y == selection_start.y && document_space_y == selection_end.y {
		draw_text_line_visual_selection_starts_and_ends_on_same_line(mut ctx, syntax,
			selection_highlight_color, selection_start, selection_end, screen_space_x,
			screen_space_y, document_space_y, cursor_screen_space_y, line_runes, original_line.runes())
		return
	}

	if document_space_y == selection_start.y && document_space_y < selection_end.y {
		draw_text_line_visual_selection_starts_on_same_but_ends_after(mut ctx, syntax,
			selection_highlight_color, selection_start, selection_end, screen_space_x,
			screen_space_y, document_space_y, cursor_screen_space_y, line_runes, original_line.runes())
		return
	}

	if document_space_y > selection_start.y && document_space_y == selection_end.y {
		draw_text_line_visual_selection_starts_before_but_ends_on_line(mut ctx, syntax,
			selection_highlight_color, selection_start, selection_end, screen_space_x,
			screen_space_y, document_space_y, cursor_screen_space_y, line_runes, original_line.runes())
		return
	}

	draw_text_line_visual_selection_between_start_and_end(mut ctx, syntax, selection_highlight_color,
		selection_start, selection_end, screen_space_x, screen_space_y, document_space_y,
		cursor_screen_space_y, line_runes, original_line.runes())
}

fn draw_text_line_visual_selection_between_start_and_end(mut ctx draw.Contextable,
	syntax workspace.Syntax,
	selection_highlight_color Color,
	selection_start Pos, selection_end Pos,
	screen_space_x int, screen_space_y int, document_space_y int,
	cursor_screen_space_y int,
	line_runes []rune,
	original_line_runes []rune) {
	ctx.set_bg_color(
		r: selection_highlight_color.r
		g: selection_highlight_color.g
		b: selection_highlight_color.b
	)
	ctx.draw_text(screen_space_x + 1, screen_space_y + 1, line_runes.string())
	ctx.reset_bg_color()
}

fn draw_text_line_visual_selection_starts_and_ends_on_same_line(mut ctx draw.Contextable,
	syntax workspace.Syntax,
	selection_highlight_color Color,
	selection_start Pos, selection_end Pos,
	screen_space_x int, screen_space_y int, document_space_y int,
	cursor_screen_space_y int,
	line_runes []rune,
	original_line_runes []rune
) {
	mut x_offset := 0
	tab_count := original_line_runes[..selection_start.x].string().count('\t')
	selection_x_offset := tab_count * 3
	pre_sel := line_runes[..selection_start.x + selection_x_offset]
	sel := line_runes[selection_start.x + x_offset + selection_x_offset..selection_end.x +
		selection_x_offset]
	post_sel := line_runes[selection_end.x + selection_x_offset..]

	if pre_sel.len != 0 {
		if screen_space_y == cursor_screen_space_y {
			ctx.set_bg_color(r: 53, g: 53, b: 53)
		}
		draw_text_line_as_segments(mut ctx, syntax, screen_space_x + x_offset, screen_space_y,
			document_space_y, pre_sel.string())
		x_offset += pre_sel.len
	}

	if sel.len != 0 {
		ctx.set_bg_color(
			r: selection_highlight_color.r
			g: selection_highlight_color.g
			b: selection_highlight_color.b
		)
		ctx.draw_text(screen_space_x + x_offset + 1, screen_space_y + 1, sel.string())
		ctx.reset_bg_color()
		x_offset += sel.len
	}

	if post_sel.len != 0 {
		if screen_space_y == cursor_screen_space_y {
			ctx.set_bg_color(r: 53, g: 53, b: 53)
		}
		draw_text_line_as_segments(mut ctx, syntax, screen_space_x + x_offset, screen_space_y,
			document_space_y, post_sel.string())
		x_offset += post_sel.len
	}
}

fn draw_text_line_visual_selection_starts_on_same_but_ends_after(mut ctx draw.Contextable,
	syntax workspace.Syntax,
	selection_highlight_color Color,
	selection_start Pos, selection_end Pos,
	screen_space_x int, screen_space_y int, document_space_y int,
	cursor_screen_space_y int,
	line_runes []rune,
	original_line_runes []rune
) {
	mut x_offset := 0
	tab_count := original_line_runes[..selection_start.x].string().count('\t')
	selection_x_offset := tab_count * 3
	pre_sel := line_runes[..selection_start.x + selection_x_offset]
	sel := line_runes[selection_start.x + selection_x_offset..]

	if pre_sel.len != 0 {
		if screen_space_y == cursor_screen_space_y {
			ctx.set_bg_color(r: 53, g: 53, b: 53)
		}
		draw_text_line_as_segments(mut ctx, syntax, screen_space_x + x_offset, screen_space_y,
			document_space_y, pre_sel.string())
		x_offset += pre_sel.len
	}

	if sel.len != 0 {
		ctx.set_bg_color(
			r: selection_highlight_color.r
			g: selection_highlight_color.g
			b: selection_highlight_color.b
		)
		ctx.draw_text(screen_space_x + x_offset + 1, screen_space_y + 1, sel.string())
		ctx.reset_bg_color()
		x_offset += sel.len
	}
}

fn draw_text_line_visual_selection_starts_before_but_ends_on_line(mut ctx draw.Contextable,
	syntax workspace.Syntax,
	selection_highlight_color Color,
	selection_start Pos, selection_end Pos,
	screen_space_x int, screen_space_y int, document_space_y int,
	cursor_screen_space_y int,
	line_runes []rune,
	original_line_runes []rune
) {
	mut x_offset := 0
	mut sel_end_x := selection_end.x
	tab_count := original_line_runes[..sel_end_x].string().count('\t')
	selection_x_offset := tab_count * 3
	sel_end_x += selection_x_offset
	if sel_end_x > line_runes.len {
		sel_end_x = line_runes.len
	}
	pre_end := line_runes[..sel_end_x]
	post_end := line_runes[sel_end_x..]

	if pre_end.len != 0 {
		ctx.set_bg_color(
			r: selection_highlight_color.r
			g: selection_highlight_color.g
			b: selection_highlight_color.b
		)
		ctx.draw_text(screen_space_x + x_offset + 1, screen_space_y + 1, pre_end.string())
		ctx.reset_bg_color()
		x_offset += pre_end.len
	}

	if screen_space_y == cursor_screen_space_y {
		ctx.set_bg_color(r: 53, g: 53, b: 53)
	}
	draw_text_line_as_segments(mut ctx, syntax, screen_space_x + x_offset, screen_space_y,
		document_space_y, post_end.string())
	x_offset += post_end.len
}

fn draw_text_line_as_segments(mut ctx draw.Contextable,
	syntax workspace.Syntax,
	screen_space_x int, screen_space_y int,
	document_space_y int,
	line string
) {
	segments, _ := resolve_line_segments(syntax, line, screen_space_y, document_space_y,
		false)

	if segments.len == 0 {
		ctx.draw_text(screen_space_x + 1, screen_space_y + 1, line)
		return
	}

	mut pos := 0
	for i, segment in segments {
		// render text before next segment
		if segment.start > pos {
			s := line.runes()[pos..segment.start].string()
			ctx.draw_text(screen_space_x + 1 + pos, screen_space_y + 1, s)
		}

		color := segment.fg_color
		s := line.runes()[segment.start..segment.end].string()
		ctx.set_color(r: color.r, g: color.g, b: color.b)
		ctx.draw_text(screen_space_x + 1 + segment.start, screen_space_y + 1, s)
		ctx.reset_color()
		pos = segment.end
		if i == segments.len - 1 && segment.end < line.len {
			final := line.runes()[segment.end..line.runes().len].string()
			ctx.draw_text(screen_space_x + 1 + pos, screen_space_y + 1, final)
		}
	}
}

enum SegmentKind {
	a_string  = 1
	a_comment = 2
	a_key     = 3
	a_lit     = 4
}

struct LineSegment {
	start            int
	end              int
	y                int
	document_space_y int
	typ              SegmentKind
	fg_color         Color
}

fn LineSegment.new_key(start int, line_y int, document_space_y int, end int) LineSegment {
	return LineSegment{
		start:            start
		end:              end
		y:                line_y
		document_space_y: document_space_y
		typ:              .a_key
		fg_color:         Color{255, 126, 182}
	}
}

fn LineSegment.new_literal(start int, line_y int, document_space_y int, end int) LineSegment {
	return LineSegment{
		start:            start
		end:              end
		y:                line_y
		document_space_y: document_space_y
		typ:              .a_lit
		fg_color:         Color{87, 215, 217}
	}
}

fn LineSegment.new_string(start int, line_y int, document_space_y int, end int) LineSegment {
	return LineSegment{
		start:            start
		end:              end
		y:                line_y
		document_space_y: document_space_y
		typ:              .a_string
		fg_color:         Color{87, 215, 217}
	}
}

fn LineSegment.new_comment(start int, line_y int, document_space_y int, end int) LineSegment {
	return LineSegment{
		start:            start
		end:              end
		y:                line_y
		document_space_y: document_space_y
		typ:              .a_comment
		fg_color:         Color{130, 130, 130}
	}
}

fn resolve_line_segments(syntax workspace.Syntax, line string, line_y int, document_space_y int, is_multiline_comment bool) ([]LineSegment, bool) {
	mut segments := []LineSegment{}
	mut is_multiline_commentx := is_multiline_comment
	line_runes := line.runes()
	for i := 0; i < line_runes.len; i++ {
		start := i
		// '//' comment
		if i > 0 && line_runes[i - 1] == `/` && line_runes[i] == `/` {
			segments << LineSegment.new_comment(start - 1, line_y, document_space_y, line_runes.len)
			break
		}

		// '#' comment
		if line_runes[i] == `#` {
			segments << LineSegment.new_comment(start, line_y, document_space_y, line_runes.len)
			break
		}

		// /* comment
		// (unless it's /* line_runes */ which is a single line_runes)
		if i > 0 && line_runes[i - 1] == `/` && line_runes[i] == `*`
			&& !(line_runes[line_runes.len - 2] == `*` && line_runes[line_runes.len - 1] == `/`) {
			// all after /* is  a comment
			segments << LineSegment.new_comment(start, line_y, document_space_y, line_runes.len)
			is_multiline_commentx = true
			break
		}
		// end of /* */
		if i > 0 && line_runes[i - 1] == `*` && line_runes[i] == `/` {
			// all before */ is still a comment
			segments << LineSegment.new_comment(0, line_y, document_space_y, start + 1)
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
			segments << LineSegment.new_string(start, line_y, document_space_y, i + 1)
		}

		if line_runes[i] == `"` {
			i++
			for i < line_runes.len - 1 && line_runes[i] != `"` {
				i++
			}
			if i >= line_runes.len {
				i = line_runes.len - 1
			}
			segments << LineSegment.new_string(start, line_y, document_space_y, i + 1)
		}

		if line_runes[i] == `\`` {
			i++
			for i < line_runes.len - 1 && line_runes[i] != `\`` {
				i++
			}
			if i >= line_runes.len {
				i = line_runes.len - 1
			}
			segments << LineSegment.new_string(start, line_y, document_space_y, i + 1)
		}

		// key
		for i < line.runes().len && is_alpha_underscore(int(line.runes()[i])) {
			i++
		}
		word := line.runes()[start..i].string()
		if word in syntax.literals {
			segments << LineSegment.new_literal(start, line_y, document_space_y, i)
		} else if word in syntax.keywords {
			segments << LineSegment.new_key(start, line_y, document_space_y, i)
		}
	}
	return segments, is_multiline_commentx
}

fn (mut view View) draw_text_line_number(mut ctx draw.Contextable, y int) {
	cursor_screenspace_y := view.cursor.pos.y - view.from
	ctx.set_color(r: 117, g: 118, b: 120)

	mut line_num_str := '${view.from + y + 1}'
	if view.config.relative_line_numbers {
		if y < cursor_screenspace_y {
			line_num_str = '${cursor_screenspace_y - y}'
		} else if cursor_screenspace_y == y {
			line_num_str = '${view.from + y + 1}'
		} else if y > cursor_screenspace_y {
			line_num_str = '${y - cursor_screenspace_y}'
		}
	}
	ctx.draw_text(view.x - line_num_str.runes().len, y + 1, line_num_str)
	ctx.reset_color()
}

fn (mut view View) draw_line_show_whitespace(mut ctx tui.Context, i int, line_cpy string) {
	if i == view.cursor.pos.y {
		mut xx := 0
		for ci, c in line_cpy {
			if ci > ctx.window_width {
				return
			}
			match c {
				`\t` {
					ctx.set_color(r: 120, g: 120, b: 120)
					ctx.draw_text(view.x + xx + 1, i + 1, '->->')
					ctx.reset_color()
					xx += 4
				}
				` ` {
					ctx.set_color(r: 120, g: 120, b: 120)
					ctx.draw_text(view.x + xx + 1, i + 1, '·')
					ctx.reset_color()
					xx += 1
				}
				else {
					ctx.draw_text(view.x + xx + 1, i + 1, c.ascii_str())
					xx += 1
				}
			}
		}
		ctx.reset_bg_color()
	} else {
		mut xx := 0
		for ci, c in line_cpy {
			if ci > ctx.window_width {
				return
			}
			match c {
				`\t` {
					ctx.set_color(r: 120, g: 120, b: 120)
					ctx.draw_text(view.x + xx + 1, i + 1, '->->')
					ctx.reset_color()
					xx += 4
				}
				` ` {
					ctx.set_color(r: 120, g: 120, b: 120)
					ctx.draw_text(view.x + xx + 1, i + 1, '·')
					ctx.reset_color()
					xx += 1
				}
				else {
					ctx.draw_text(view.x + xx + 1, i + 1, c.ascii_str())
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
fn set_cursor_to_block(mut ctx draw.Contextable) {
	ctx.write('\x1b[0 q')
}

fn set_cursor_to_underline(mut ctx draw.Contextable) {
	ctx.write('\x1b[4 q')
}

fn set_cursor_to_vertical_bar(mut ctx draw.Contextable) {
	ctx.write('\x1b[6 q')
}

struct Color {
	r u8
	g u8
	b u8
}

fn paint_shape_text(mut ctx draw.Contextable, x int, y int, color Color, text string) {
	ctx.set_color(r: color.r, g: color.g, b: color.b)
	ctx.reset_bg_color()
	ctx.draw_text(x, y, text)
}

fn paint_text_on_background(mut ctx draw.Contextable, x int, y int, bg_color Color, fg_color Color, text string) {
	ctx.set_bg_color(r: bg_color.r, g: bg_color.g, b: bg_color.b)
	ctx.set_color(r: fg_color.r, g: fg_color.g, b: fg_color.b)
	ctx.draw_text(x, y, text)
}

fn (mut view View) exec(op chords.Op) {
	match op.kind {
		.nop {
			return
		}
		.paste {
			for _ in 0 .. op.repeat {
				view.p()
			}
		}
		.mode {
			match op.mode {
				.insert { view.i() }
			}
		}
		.move {
			match op.direction {
				.left {
					for _ in 0 .. op.repeat {
						view.h()
					}
				}
				.right {
					for _ in 0 .. op.repeat {
						view.l()
					}
				}
				.up {
					for _ in 0 .. op.repeat {
						view.k()
					}
				}
				.down {
					for _ in 0 .. op.repeat {
						view.j()
					}
				}
				.word {
					for _ in 0 .. op.repeat {
						view.w()
					}
				}
				.word_end {
					for _ in 0 .. op.repeat {
						view.e()
					}
				}
				.word_reverse {
					for _ in 0 .. op.repeat {
						view.b()
					}
				}
				else {}
			}
		}
		.delete {
			match op.direction {
				.word { panic('delete word not implemented') }
				.inside_word { panic('delete inside word not implemented') }
				else {}
			}
		}
	}
}

fn (mut view View) insert_tab() {
	if view.config.insert_tabs_not_spaces {
		view.insert_text('\t')
		return
	}
	view.insert_text(' '.repeat(4))
}

fn (mut view View) visual_indent() {
	mut start := view.cursor.selection_start().y
	mut end := view.cursor.selection_end().y

	prefix := if view.config.insert_tabs_not_spaces { '\t' } else { ' '.repeat(4) }

	for i := start; i < end + 1; i++ {
		view.buffer.lines[i] = '${prefix}${view.buffer.lines[i]}'
	}
}

fn (mut view View) visual_unindent() {
	mut start := view.cursor.selection_start().y
	mut end := view.cursor.selection_end().y

	prefix := if view.config.insert_tabs_not_spaces { '\t' } else { ' '.repeat(4) }

	for i := start; i < end + 1; i++ {
		view.buffer.lines[i] = subtract_prefix_from_line(prefix, view.buffer.lines[i])
	}
}

fn subtract_prefix_from_line(prefix string, line string) string {
	if line.len > prefix.len {
		line_prefix := line.substr(0, prefix.len)
		if line_prefix == prefix {
			return line.substr(prefix.len, line.len)
		}
	}
	return line
}

fn (mut view View) save_file() ! {
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
	y := view.cursor.pos.y
	line := view.buffer.lines[y]
	if line.len == 0 {
		view.buffer.lines[y] = '${s}'
		view.cursor.pos.x = s.runes().len
		return
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
			view.cursor.pos.y = view.cursor.selection_start().y
		}
		view.cursor.selection_start_pos = Pos{-1, -1}
		view.clamp_cursor_within_document_bounds()
		view.scroll_from_and_to()
	}
	view.chord.reset()
	view.cursor.pos.x -= 1
	view.clamp_cursor_x_pos()
	view.cmd_buf.clear()
	view.search.clear()

	// if current line only contains whitespace prefix clear the line
	line := view.buffer.lines[view.cursor.pos.y]
	whitespace_prefix := resolve_whitespace_prefix(line)
	if whitespace_prefix.len == line.len {
		view.buffer.lines[view.cursor.pos.y] = ''
	}

	view.buffer.update_undo_history()
	view.buffer.auto_close_chars = []

	view.leader_state.reset()
}

fn (mut view View) escape_replace() {
	view.leader_state.mode = .normal
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
		if view.from < 0 {
			view.from = 0
		}
		return
	}

	if view.cursor.pos.y + 1 > view.to && view.to >= view.height - 2 { // TODO(tauraamui): I really need to define the magic numbers we're using any why
		diff := view.cursor.pos.y + 1 - view.to
		view.from += diff
	}
}

fn (mut view View) clamp_cursor_within_document_bounds() {
	if view.cursor.pos.y < 0 {
		view.cursor.pos.y = 0
	}
	if view.cursor.pos.y > view.buffer.lines.len - 1 {
		view.cursor.pos.y = view.buffer.lines.len - 1
	}
}

fn (mut view View) num_of_lines_in_view() int {
	return view.to - view.from
}

fn (mut view View) clamp_cursor_x_pos() int {
	view.clamp_cursor_within_document_bounds()
	line_len := view.buffer.lines[view.cursor.pos.y].runes().len
	if line_len == 0 {
		view.cursor.pos.x = 0
		return 0
	}
	if view.leader_state.mode == .insert {
		if view.cursor.pos.x > line_len {
			view.cursor.pos.x = line_len
		}
	} else {
		diff := view.cursor.pos.x - (line_len - 1)
		if diff > 0 {
			view.cursor.pos.x = line_len - 1
			return diff
		}
	}
	if view.cursor.pos.x < 0 {
		view.cursor.pos.x = 0
	}
	return 0
}

fn (view View) code_view_height() int {
	return view.height - 2
}

fn (mut view View) cmd() {
	view.leader_state.mode = .command
	view.cmd_buf.prepare_for_input()
}

fn (mut view View) exec_cmd() bool {
	return match view.cmd_buf.line {
		':q' {
			exit(0)
			true
		}
		':toggle whitespace' {
			view.show_whitespace = !view.show_whitespace
			true
		}
		else {
			false
		}
	}
}

fn (mut view View) search() {
	view.leader_state.mode = .search
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
	view.move_cursor_down(1)
	view.clamp_cursor_x_pos()
}

fn (mut view View) k() {
	view.move_cursor_up(1)
	view.clamp_cursor_x_pos()
}

fn (mut view View) i() {
	view.leader_state.mode = .insert
	view.clamp_cursor_x_pos()
	view.buffer.snapshot()
}

fn (mut view View) v() {
	view.leader_state.mode = .visual
	view.cursor.selection_start_pos = view.cursor.pos
}

fn (mut view View) shift_v() {
	view.leader_state.mode = .visual_line
	view.cursor.selection_start_pos = view.cursor.pos
}

fn (mut view View) r() {
	view.leader_state.mode = .replace
}

// FIX(tauraamui): there's misplaced logic in this method that should belong to
//                 the method "visual_line_y" whereby it inserts a leading and trailing
//                 newline char before and after the "selection"
fn (mut view View) visual_y() {
	mut str_builder := strings.new_builder(1024)
	defer {
		str_builder.clear()
		view.escape()
	}

	start := view.cursor.selection_start()
	end := view.cursor.selection_end()
	// *
	if start.y == end.y {
		// selection begins and ends on the same line
		// *
		line := view.buffer.lines[start.y].runes()
		str_builder.write_runes(line[start.x..end.x + 1])
		view.clipboard.copy(str_builder.str())
		return
	}

	start_line := view.buffer.lines[start.y].runes()
	str_builder.write_runes(start_line[start.x..start_line.len])
	str_builder.write_rune(`\n`)

	diff := end.y - start.y
	if diff >= 1 {
		for ll in view.buffer.lines[start.y + 1..end.y] {
			str_builder.write_string(ll)
			str_builder.write_rune(`\n`)
		}
	}

	end_line := view.buffer.lines[end.y].runes()
	str_builder.write_runes(end_line[..end.x + 1])
	/*
	if end.x == end_line.len {
		str_builder.write_rune(`\n`)
	}
	*/

	view.clipboard.copy(str_builder.str())
}

fn (mut view View) visual_line_y() {
	start := view.cursor.selection_start().y
	mut end := view.cursor.selection_end().y
	assert end >= 0
	assert end < view.buffer.lines.len
	// TODO(tauraamui): check if this bounds guard is actually needed at all
	if end + 1 >= view.buffer.lines.len {
		end = view.buffer.lines.len - 1
	}
	// view.copy_lines_into_clipboard(start, end)
	view.clipboard.copy('\n${arrays.join_to_string(view.buffer.lines[start..end + 1].clone(),
		'\n', fn (s string) string {
		return s
	})}\n')
	view.escape()
}

fn (mut view View) x() {
	defer { view.clamp_cursor_x_pos() }
	x := view.cursor.pos.x
	y := view.cursor.pos.y

	line := view.buffer.lines[y].runes()
	start := line[..x]
	end := line[x + 1..]
	view.buffer.lines[y] = '${start.string()}${end.string()}'
}

fn (mut view View) copy_lines_into_clipboard(start int, end int) {
	assert start >= 0
	assert end >= 0
	assert end + 1 <= view.buffer.lines.len
	view.clipboard.copy(arrays.join_to_string(view.buffer.lines[start..end + 1].clone(),
		'\n', fn (s string) string {
		return s
	}))
}

fn (mut view View) visual_d(overwrite_y_lines bool) {}

fn (mut view View) visual_line_d(overwrite_y_lines bool) {
	defer { view.clamp_cursor_within_document_bounds() }
	mut start := view.cursor.selection_start().y
	mut end := view.cursor.selection_end().y

	view.copy_lines_into_clipboard(start, end)
	before := view.buffer.lines[..start]
	after := view.buffer.lines[end + 1..]

	view.buffer.lines = before
	view.buffer.lines << after
	view.cursor.pos.y = start
	view.escape()
}

fn (mut view View) w() {
	defer { view.clamp_cursor_x_pos() }
	mut line := view.buffer.lines[view.cursor.pos.y]
	mut amount := calc_w_move_amount(view.cursor.pos, line, false)
	if amount == 0 {
		view.move_cursor_down(1)
		view.cursor.pos.x = 0
		assert view.cursor.pos.y >= 0
		assert view.cursor.pos.y < view.buffer.lines.len
		line = view.buffer.lines[view.cursor.pos.y]
		assert view.cursor.pos.x >= 0
		assert view.cursor.pos.x < line.len
		if line.len > 0 && is_whitespace(line[view.cursor.pos.x]) {
			amount = calc_w_move_amount(view.cursor.pos, line, false)
			assert amount >= 0
		}
	}
	view.cursor.pos.x += amount
}

fn (mut view View) e() {
	defer { view.clamp_cursor_x_pos() }
	mut line := view.buffer.lines[view.cursor.pos.y]
	mut amount := calc_e_move_amount(view.cursor.pos, line, false) or {
		view.cmd_buf.set_error(err.msg())
		0
	}
	if amount == 0 {
		view.move_cursor_down(1)
		view.cursor.pos.x = 0
		assert view.cursor.pos.y >= 0 && view.cursor.pos.y < view.buffer.lines.len
		line = view.buffer.lines[view.cursor.pos.y]
		amount = calc_e_move_amount(view.cursor.pos, line, false) or {
			view.cmd_buf.set_error(err.msg())
			0
		}
		assert amount >= 0
	}
	view.cursor.pos.x += amount
}

fn (mut view View) b() {
	defer { view.clamp_cursor_x_pos() }
	line := view.buffer.lines[view.cursor.pos.y]
	view.clamp_cursor_x_pos()
	amount := calc_b_move_amount(view.cursor.pos, line, false)
	if amount == 0 && view.cursor.pos.y > 0 {
		view.move_cursor_up(1)
		view.cursor.pos.x = view.buffer.lines[view.cursor.pos.y].runes().len - 1
		return
	}
	view.cursor.pos.x -= amount
}

fn (mut view View) ctrl_d() {
	view.move_cursor_down(view.num_of_lines_in_view() - 2)
	view.clamp_cursor_x_pos()
}

fn (mut view View) ctrl_u() {
	view.move_cursor_up(view.num_of_lines_in_view() - 2)
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
	view.leader_state.d_count += 1
	if view.leader_state.d_count == 1 {
		view.leader_state.mode = .pending_delete
	}
	if view.leader_state.d_count == 2 {
		index := if view.cursor.pos.y == view.buffer.lines.len {
			view.cursor.pos.y - 1
		} else {
			view.cursor.pos.y
		}
		view.copy_lines_into_clipboard(index, index)
		view.buffer.lines.delete(index)
		view.leader_state.d_count = 0
		view.clamp_cursor_within_document_bounds()
		view.leader_state.mode = .normal
	}
}

fn (mut view View) u() {
	view.buffer.undo()
}

fn (mut view View) o() {
	defer { view.move_cursor_down(1) }
	view.leader_state.mode = .insert
	y := view.cursor.pos.y
	whitespace_prefix := resolve_whitespace_prefix(view.buffer.lines[y])
	defer { view.cursor.pos.x = whitespace_prefix.len }
	if y >= view.buffer.lines.len {
		view.buffer.lines << '${whitespace_prefix}'
		return
	}
	view.buffer.lines.insert(y + 1, '${whitespace_prefix}')
}

fn (mut view View) shift_o() {
	view.leader_state.mode = .insert
	y := view.cursor.pos.y
	whitespace_prefix := resolve_whitespace_prefix(view.buffer.lines[y])
	defer { view.cursor.pos.x = whitespace_prefix.len }
	view.buffer.lines.insert(y, '${whitespace_prefix}')
}

fn (mut view View) a() {
	view.leader_state.mode = .insert
	view.cursor.pos.x += 1
}

fn (mut view View) shift_a() {
	view.dollar()
	view.a()
}

@[direct_array_access]
fn (mut view View) p() {
	mut clipboard_contents := view.clipboard.paste().runes()
	if clipboard_contents.len == 0 {
		return
	}

	if clipboard_contents[0] == `\n` && clipboard_contents[clipboard_contents.len - 1] == `\n` {
		lines := clipboard_contents[1..clipboard_contents.len - 1].string().split_into_lines()
		view.buffer.lines.insert(view.cursor.pos.y + 1, lines)
		view.move_cursor_down(lines.len)
		return
	}

	start_y := view.cursor.pos.y
	mut after_current_cursor_x_pos := ''
	for i := 0; i < clipboard_contents.len; i++ {
		if clipboard_contents[i] == `\n` {
			if after_current_cursor_x_pos.len == 0
				&& view.cursor.pos.x < view.buffer.lines[start_y].len {
				after_current_cursor_x_pos = view.buffer.lines[start_y][view.cursor.pos.x..]
				view.buffer.lines[start_y] = view.buffer.lines[start_y][..view.cursor.pos.x]
			}
			view.buffer.lines.insert(view.cursor.pos.y + 1, '')
			view.move_cursor_down(1)
			continue
		}
		view.insert_text('${clipboard_contents[i]}')
	}
	current_x_pos := view.cursor.pos.x
	view.insert_text(after_current_cursor_x_pos)
	view.cursor.pos.x = current_x_pos
}

fn (mut view View) visual_p() {}

fn (mut view View) visual_line_p() {
	defer { view.clamp_cursor_within_document_bounds() }
	mut start := view.cursor.selection_start().y
	mut end := view.cursor.selection_end().y

	before := view.buffer.lines[..start]
	after := view.buffer.lines[end + 1..]

	copied_lines := view.clipboard.paste()

	view.buffer.lines = before
	view.buffer.lines << after
	view.cursor.pos.y = start
	// FIX(tauraamui): adjust pasting behaviour if the copy was not from a full line
	view.buffer.lines.insert(view.cursor.pos.y, copied_lines)
	view.move_cursor_down(copied_lines.len)
	view.escape()
}

fn (mut view View) enter() {
	y := view.cursor.pos.y
	mut whitespace_prefix := resolve_whitespace_prefix(view.buffer.lines[y])
	if whitespace_prefix.len == view.buffer.lines[y].len { // if the current line only has whitespace on it
		view.buffer.lines[y] = ''
		whitespace_prefix = ''
		view.cursor.pos.x = 0
	}
	after_cursor := view.buffer.lines[y].runes()[view.cursor.pos.x..].string()
	view.buffer.lines[y] = view.buffer.lines[y].runes()[..view.cursor.pos.x].string()
	view.buffer.lines.insert(y + 1, '${whitespace_prefix}${after_cursor}')
	view.move_cursor_down(1)
	view.cursor.pos.x = whitespace_prefix.len
	view.clamp_cursor_x_pos()
}

fn resolve_whitespace_prefix(line string) string {
	mut prefix_ends := 0
	for i, c in line {
		if !is_whitespace(c) {
			prefix_ends = i
			return line[..prefix_ends]
		}
	}
	return line
}

fn (mut view View) backspace() {
	y := view.cursor.pos.y

	if view.cursor.pos.x == 0 && y == 0 {
		return
	}

	mut line := view.buffer.lines[y]

	if view.cursor.pos.x == 0 {
		previous_line := view.buffer.lines[y - 1]
		view.buffer.lines[y - 1] = '${previous_line}${view.buffer.lines[y]}'
		view.buffer.lines.delete(y)
		view.move_cursor_up(1)
		view.cursor.pos.x = previous_line.len

		if view.cursor.pos.y < 0 {
			view.cursor.pos.y = 0
		}
		return
	}

	if view.cursor.pos.x == line.len {
		view.buffer.lines[y] = line.runes()[..line.len - 1].string()
		view.cursor.pos.x = view.buffer.lines[y].len
		return
	}

	before := line.runes()[..view.cursor.pos.x - 1].string()
	after := line.runes()[view.cursor.pos.x..].string()
	view.buffer.lines[y] = '${before}${after}'
	view.cursor.pos.x -= 1
	if view.cursor.pos.x < 0 {
		view.cursor.pos.x = 0
	}
}

fn (mut view View) left() {
	view.cursor.pos.x -= 1
	if view.cursor.pos.x < 0 {
		view.cursor.pos.x = 0
	}
}

fn (mut view View) right() {
	view.cursor.pos.x += 1
	view.clamp_cursor_x_pos()
}

fn count_repeated_sequence(char_rune rune, line []rune) int {
	for i, r in line {
		if r != char_rune {
			return i
		}
		if i + 1 == line.len {
			return i + 1
		}
	}
	return 0
}

fn calc_w_move_amount(cursor_pos Pos, line string, recursive_call bool) int {
	if line.len == 0 {
		return 0
	}
	line_chars := line.runes()

	if r := is_special(line_chars[cursor_pos.x]) {
		if cursor_pos.x + 1 >= line_chars.len {
			return 0
		}
		if recursive_call {
			return 0
		}
		for i, c in line_chars[cursor_pos.x + 1..] {
			if next_r := is_special(c) {
				if r != next_r {
					return i + 1
				}
				continue
			}
			if is_whitespace(c) {
				return calc_w_move_amount(Pos{ x: cursor_pos.x + i +
					1, y: cursor_pos.y }, line, true) + i + 1
			}
			return i + 1
		}
	}

	if is_whitespace(line_chars[cursor_pos.x]) {
		if cursor_pos.x + 1 >= line_chars.len {
			return 0
		}
		for i, c in line_chars[cursor_pos.x + 1..] {
			if !is_whitespace(c) {
				return i + 1
			}
		}
	}

	if is_alpha(line_chars[cursor_pos.x]) {
		if cursor_pos.x + 1 >= line_chars.len {
			return 0
		}
		for i, c in line_chars[cursor_pos.x + 1..] {
			if is_non_alpha(c) {
				return calc_w_move_amount(Pos{ x: cursor_pos.x + i +
					1, y: cursor_pos.y }, line, true) + i + 1
			}
		}
	}

	return 0
}

enum PositionWithinWord as u8 {
	start
	floating
	single_letter
	end
}

fn is_special(r rune) ?rune {
	if !is_whitespace(r) && is_non_alpha(r) && !(r == `\n` || r == `\r`) {
		return r
	}
	return none
}

fn calc_e_move_amount(cursor_pos Pos, line string, recursive_call bool) !int {
	if line.len == 0 {
		return 0
	}
	line_chars := line.runes()

	if r := is_special(line_chars[cursor_pos.x]) {
		if cursor_pos.x + 1 >= line_chars.len {
			return 0
		}
		repeated := count_repeated_sequence(r, line_chars[cursor_pos.x + 1..])
		if repeated > 0 {
			return repeated
		}

		if recursive_call {
			return 0
		}
		// basically this means we've hit a single floating special

		return calc_e_move_amount(Pos{ x: cursor_pos.x + 1, y: cursor_pos.y }, line, true) or {
			return err
		} + 1
	}

	if is_whitespace(line_chars[cursor_pos.x]) {
		if cursor_pos.x + 1 >= line_chars.len {
			return 0
		}
		mut end_of_whitespace_set := 0
		for i, c in line_chars[cursor_pos.x..] {
			if !is_whitespace(c) {
				end_of_whitespace_set = i
				break
			}
		}
		return calc_e_move_amount(Pos{ x: cursor_pos.x + end_of_whitespace_set, y: cursor_pos.y }, line, true) or {
			return err
		} + end_of_whitespace_set
	}

	if is_alpha(line_chars[cursor_pos.x]) {
		if cursor_pos.x + 1 >= line_chars.len {
			return 0
		}
		mut word_position := find_position_within_word(cursor_pos.x, line_chars)
		if word_position == .start {
			word_position = .floating
		}
		match word_position {
			.floating {
				for i, c in line_chars[cursor_pos.x + 1..] {
					if is_non_alpha(c) {
						return i
					}
				}
			}
			.single_letter {
				if recursive_call {
					return 0
				}
			}
			else {}
		}
		return calc_e_move_amount(Pos{ x: cursor_pos.x + 1, y: cursor_pos.y }, line, true) or {
			return err
		} + 1
	}

	return error('unable to provide move calculation') // TODO(tauraamui) -> improve error string structure and meaning/grammar/syntax
}

fn find_position_within_word(cursor_pos_x int, line_chars []rune) PositionWithinWord {
	mut position := PositionWithinWord.floating
	if cursor_pos_x == 0 {
		if is_non_alpha(line_chars[cursor_pos_x + 1]) {
			return .single_letter
		}
		return .start
	}
	if is_non_alpha(line_chars[cursor_pos_x - 1]) {
		position = .start
	}
	if is_non_alpha(line_chars[cursor_pos_x + 1]) {
		if position == .start {
			position = .single_letter
		} else {
			position = .end
		}
	}
	return position
}

// status_green            = Color { 145, 237, 145 }
fn calc_b_move_amount(cursor_pos Pos, line string, recursive_call bool) int {
	if line.len == 0 {
		return 0
	}
	if cursor_pos.x - 1 < 0 {
		return 0
	}
	line_chars := line.runes()

	if r := is_special(line_chars[cursor_pos.x]) {
		if cursor_pos.x - 1 < 0 {
			return 0
		}
		mut max_i := 0
		for i, c in line_chars[..cursor_pos.x].reverse() {
			max_i = i
			if next_r := is_special(c) {
				if next_r == r {
					continue
				}
				if i == 0 {
					return
						calc_b_move_amount(Pos{ x: cursor_pos.x - 1, y: cursor_pos.y }, line, true) +
						1
				}
				return i
			}
			// find out if on single special char
			if i == 0 && !recursive_call {
				return
					calc_b_move_amount(Pos{ x: cursor_pos.x - 1, y: cursor_pos.y }, line, true) + 1
			}
			return i
		}
		return max_i + 1
	}

	if is_whitespace(line_chars[cursor_pos.x]) {
		if cursor_pos.x - 1 < 0 {
			return 0
		}
		mut max_i := 0
		for i, c in line_chars[..cursor_pos.x].reverse() {
			max_i = i
			if !is_whitespace(c) {
				return calc_b_move_amount(Pos{ x: cursor_pos.x - (i +
					1), y: cursor_pos.y }, line, true) + i + 1
			}
		}
		return max_i + 1 // NOTE(tauraamui): -> Really this behaviour is wrong, if nothing but whitespace between here and line start,
		// then should be called recursively again by caller (not us/here) for the next line above.
	}

	if is_alpha(line_chars[cursor_pos.x]) {
		if cursor_pos.x - 1 < 0 {
			return 0
		}
		mut max_i := 0
		for i, c in line_chars[..cursor_pos.x].reverse() {
			max_i = i
			if is_non_alpha(c) {
				if i == 0 {
					if recursive_call {
						return 0
					}
					return
						calc_b_move_amount(Pos{ x: cursor_pos.x - 1, y: cursor_pos.y }, line, true) +
						1
				}
				return i
			}
		}
		return max_i + 1
	}

	return 0
}

fn (mut view View) jump_cursor_up_to_next_blank_line() {
	view.clamp_cursor_within_document_bounds()
	if view.cursor.pos.y == 0 {
		return
	}
	if view.buffer.lines.len == 0 {
		return
	}

	for i := view.cursor.pos.y; i > 0; i-- {
		if i == view.cursor.pos.y {
			continue
		}
		if view.buffer.lines[i].len == 0 {
			view.move_cursor_up(view.cursor.pos.y - i)
			return
		}
	}

	view.move_cursor_up(view.cursor.pos.y)
}

fn (mut view View) jump_cursor_down_to_next_blank_line() {
	view.clamp_cursor_within_document_bounds()
	if view.buffer.lines.len == 0 {
		return
	}
	if view.cursor.pos.y == view.buffer.lines.len {
		return
	}

	for i := view.cursor.pos.y; i < view.buffer.lines.len; i++ {
		if i == view.cursor.pos.y {
			continue
		}
		if view.buffer.lines[i].len == 0 {
			view.move_cursor_down(i - view.cursor.pos.y)
			return
		}
	}

	view.move_cursor_down(view.buffer.lines.len - view.cursor.pos.y)
}

fn (mut view View) left_square_bracket() {
	view.right_bracket_press_count = 0
	view.left_bracket_press_count += 1

	if view.left_bracket_press_count >= 2 {
		view.move_cursor_up(view.cursor.pos.y)
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

fn (mut view View) replace_char(code u8, str string) {
	if code < 32 {
		return
	}
	line := view.buffer.lines[view.cursor.pos.y].runes()
	start := line[..view.cursor.pos.x]
	end := line[view.cursor.pos.x + 1..]
	view.buffer.lines[view.cursor.pos.y] = '${start.string()}${str}${end.string()}'
}

fn (mut view View) close_pair(c string) bool {
	pair := auto_pairs[c] or { return false }
	if view.buffer.auto_close_chars[view.buffer.auto_close_chars.len - 1] == pair {
		view.buffer.auto_close_chars.delete_last()
		return true
	}
	return false
}

fn (mut view View) close_pair_or_insert(c string) {
	if view.buffer.auto_close_chars.len == 0 {
		view.insert_text(c)
	} else if view.close_pair(c) {
		view.cursor.pos.x += 1
	} else {
		view.insert_text(c)
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

fn is_non_alpha(c rune) bool {
	return c != `_` && !is_alpha(c)
}

fn is_alpha(r rune) bool {
	return (r >= `a` && r <= `z`) || (r >= `A` && r <= `Z`) || (r >= `0` && r <= `9`)
}

fn is_whitespace(r rune) bool {
	return r == ` ` || r == `\t` || r == `\n` || r == `\r`
}

fn is_alpha_underscore(r int) bool {
	return is_alpha(u8(r)) || u8(r) == `_` || u8(r) == `#` || u8(r) == `$`
}
