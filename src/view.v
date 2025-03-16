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
import term
import term.ui as tui
import log
import datatypes
import strconv
import regex
import lib.clipboardv2
import lib.buffer
import lib.workspace
import lib.chords
import lib.draw
import lib.core
import lib.ui

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

const auto_pairs = {
	'}': '{'
	']': '['
	')': '('
	'"': '"'
	"'": "'"
}

struct ViewLeaderState {
mut:
	mode    core.Mode
	special bool
	normal  bool
	suffix  []string
	// TODO(tauraamui) [23/01/25] look into decomissioning these
	d_count int
	f_count int
	b_count int
	g_count int
	z_count int
	x_count int
}

fn (mut state ViewLeaderState) reset() {
	state.special = false
	state.normal  = false
	state.mode    = .normal
	state.suffix.clear()
	state.d_count = 0
	state.f_count = 0
	state.b_count = 0
	state.g_count = 0
	state.z_count = 0
	state.x_count = 0
}

struct View {
pub:
	file_path string
mut:
	log                       log.Log
	path                      string
	branch                    string
	config                    workspace.Config
	leader_state              ViewLeaderState
	buf_view                  ui.BufferView
	buffer                    buffer.Buffer
	leader_key                string = " "
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
	clipboard                 clipboardv2.Clipboard
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

fn (code CmdCode) color() draw.Color {
	return match code {
		.blank { draw.Color{230, 230, 230} }
		.successful { draw.Color{100, 230, 110} }
		.unsuccessful { draw.Color{230, 110, 100} }
		.unrecognised { draw.Color{230, 110, 100} }
		.disabled { draw.Color{150, 150, 150} }
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
			root.quit() or {
				cmd_buf.code = .unsuccessful
				cmd_buf.set_error(err.msg())
				return
			}
			cmd_buf.code = .successful
		}
		':q!' {
			root.force_quit()
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
			if cmd_buf.code == .successful {
				view.buffer.dirty = false
			}
		}
		':wq' {
			cmd_buf.code = .successful
			view.save_file() or { cmd_buf.code = .unsuccessful }
			view.buffer.dirty = false
			if cmd_buf.code == .successful {
				root.quit() or {}
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

fn open_view(mut _log log.Log, config workspace.Config, branch string, syntaxes []workspace.Syntax, _clipboard clipboardv2.Clipboard, mut buff buffer.Buffer) Viewable {
	mut res := View{
		log:             _log
		branch:          branch
		syntaxes:        syntaxes
		file_path:       buff.file_path
		config:          config
		leader_key:      config.leader_key
		leader_state:     ViewLeaderState{ mode: .normal }
		show_whitespace: false
		clipboard:       _clipboard
		buffer:          buff
		buf_view:		ui.BufferView.new(&buff)
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

interface Viewable {
	file_path string
mut:
	draw(mut draw.Contextable)
	on_key_down(draw.Event, mut Root)
	on_mouse_scroll(draw.Event)
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
	if view.leader_state.d_count == 1 || view.leader_state.z_count == 1 || view.leader_state.mode == .replace || view.leader_state.g_count == 1 || view.leader_state.f_count == 1 || view.leader_state.mode == .replacing {
		set_cursor_to_underline(mut ctx)
	}
	ctx.set_cursor_position(view.x + 1 + view.calc_cursor_x_offset(),
		view.calc_cursor_y_in_screen_space() + 1)
}

fn (mut view View) draw(mut ctx draw.Contextable) {
	view.offset_x_and_width_by_len_of_longest_line_number_str(ctx.window_width(), ctx.window_height())

	view.draw_document(mut ctx)
	// draw_lines_from := 2335
	// view.buf_view.draw(mut ctx, 0, 0, ctx.window_width(), ctx.window_height() - 2, draw_lines_from)

	ui.draw_status_line(
		mut ctx, ui.Status{
			view.leader_state.mode,
			view.cursor.pos.x, view.cursor.pos.y,
			os.base(view.path),
			ui.SearchSelection{
				active:  view.leader_state.mode == .search
				total:   view.search.total_finds
				current: view.search.current_find.match_index
			},
			view.branch,
			view.buffer.dirty
		}
	)

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

	for y, line in view.buffer.line_iterator() {
		if y < view.from || y > view.to { continue }

		screen_space_y := y - view.from

		ctx.reset_bg_color()
		ctx.reset_color()

		view.draw_text_line_number(mut ctx, screen_space_y)

		document_space_y := view.from + screen_space_y

		mut linex := term.strip_ansi(line.replace('\t', ' '.repeat(4)))
		mut max_width := view.width
		visible_len := utf8_str_visible_length(linex)
		if max_width > visible_len {
			max_width = visible_len
		}

		linex = linex.runes()[..max_width].string()
		sel_highlight_color := draw.Color{
			r: view.config.selection_highlight_color.r
			g: view.config.selection_highlight_color.g
			b: view.config.selection_highlight_color.b
		}
		draw_text_line(mut ctx, view.syntaxes[view.current_syntax_idx] or { workspace.Syntax{} },
			view.cursor, view.leader_state.mode, sel_highlight_color, view.x, screen_space_y, document_space_y,
			cursor_screen_space_y, linex, line)
	}
}

fn draw_text_line(mut ctx draw.Contextable,
	syntax workspace.Syntax,
	cursor Cursor,
	current_mode core.Mode,
	selection_highlight_color draw.Color,
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
	selection_highlight_color draw.Color,
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
	selection_highlight_color draw.Color,
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
	selection_highlight_color draw.Color,
	selection_start Pos, selection_end Pos,
	screen_space_x int, screen_space_y int, document_space_y int,
	cursor_screen_space_y int,
	line_runes []rune,
	original_line_runes []rune
) {
	ctx.set_bg_color(r: 53, g: 53, b: 53)
	defer { ctx.reset_bg_color() }
	pre_tab_count := original_line_runes[..selection_start.x].string().count('\t')
	pre_selection := line_runes[..selection_start.x + (pre_tab_count * 3)]
	draw_text_line_as_segments(mut ctx, syntax, screen_space_x, screen_space_y, document_space_y, pre_selection.string())

	sel_tab_count := original_line_runes[selection_start.x..selection_end.x].string().count('\t')
	within_selection := line_runes[selection_start.x + (pre_tab_count * 3)..selection_end.x + ((pre_tab_count + sel_tab_count) * 3)]
	ctx.set_bg_color(
		r: selection_highlight_color.r
		g: selection_highlight_color.g
		b: selection_highlight_color.b
	)
	ctx.draw_text(screen_space_x + 1 + pre_selection.len, screen_space_y + 1, within_selection.string())
	ctx.reset_bg_color()

	ctx.set_bg_color(r: 53, g: 53, b: 53)
	post_selection := line_runes[selection_end.x + ((pre_tab_count + sel_tab_count) * 3)..]
	draw_text_line_as_segments(mut ctx, syntax, screen_space_x + pre_selection.len + within_selection.len, screen_space_y, document_space_y, post_selection.string())
}

fn draw_text_line_visual_selection_starts_on_same_but_ends_after(mut ctx draw.Contextable,
	syntax workspace.Syntax,
	selection_highlight_color draw.Color,
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
	selection_highlight_color draw.Color,
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
	a_builtin = 5
}

struct LineSegment {
	start            int
	end              int
	y                int
	document_space_y int
	typ              SegmentKind
	fg_color         draw.Color
}

fn LineSegment.new_key(start int, line_y int, document_space_y int, end int) LineSegment {
	return LineSegment{
		start:            start
		end:              end
		y:                line_y
		document_space_y: document_space_y
		typ:              .a_key
		fg_color:         draw.Color{255, 126, 182}
	}
}

fn LineSegment.new_literal(start int, line_y int, document_space_y int, end int) LineSegment {
	return LineSegment{
		start:            start
		end:              end
		y:                line_y
		document_space_y: document_space_y
		typ:              .a_lit
		fg_color:         draw.Color{87, 215, 217}
	}
}

fn LineSegment.new_builtin(start int, line_y int, document_space_y int, end int) LineSegment {
	return LineSegment{
		start: start
		end: end
		y: line_y
		document_space_y: document_space_y
		typ: .a_builtin
		fg_color: draw.Color{130, 144, 250}
	}
}

fn LineSegment.new_string(start int, line_y int, document_space_y int, end int) LineSegment {
	return LineSegment{
		start:            start
		end:              end
		y:                line_y
		document_space_y: document_space_y
		typ:              .a_string
		fg_color:         draw.Color{87, 215, 217}
	}
}

fn LineSegment.new_comment(start int, line_y int, document_space_y int, end int) LineSegment {
	return LineSegment{
		start:            start
		end:              end
		y:                line_y
		document_space_y: document_space_y
		typ:              .a_comment
		fg_color:         draw.Color{130, 130, 130}
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
		} else if word in syntax.builtins {
			segments << LineSegment.new_builtin(start, line_y, document_space_y, i)
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
	pos := view.buffer.insert_tab(
		buffer.Pos{ x: view.cursor.pos.x, y: view.cursor.pos.y },
		view.config.insert_tabs_not_spaces,
	) or { return }
	view.cursor.pos.x = pos.x
	view.cursor.pos.y = pos.y
	view.scroll_from_and_to()
}

// NOTE(tauraamui) [15/01/25]: The mechanisms around selections needs to be properly
//                             thought through before this stuff is migrated to the
//                             buffer wrapper type data structure.
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

// NOTE(tauraamui) [15/01/25]: Hmm tracking which file a buffer represents should
//                             be handled by the buffer itself, so this needs to
//                             be re-worked as part of migrating this to the buffer
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
	pos := view.buffer.insert_text(buffer.Pos{ x: view.cursor.pos.x, y: view.cursor.pos.y }, s) or { return }
	view.cursor.pos.x = pos.x
	view.cursor.pos.y = pos.y
	view.scroll_from_and_to()
}

fn (mut view View) escape() {
	// TODO(tauraamui) -> completely re-write this method
	defer {
		view.cursor.selection_start_pos = Pos{-1, -1}
		view.clamp_cursor_within_document_bounds()
		view.scroll_from_and_to()
	}
	view.chord.reset()
	view.cursor.pos.x -= 1
	view.clamp_cursor_x_pos()
	view.cmd_buf.clear()
	view.search.clear()
	view.leader_state.reset()

	// if current line only contains whitespace prefix clear the line
	if view.buffer.lines.len > 0 {
		line := view.buffer.lines[view.cursor.pos.y]
		whitespace_prefix := resolve_whitespace_prefix(line)
		if whitespace_prefix.len == line.len {
			view.buffer.lines[view.cursor.pos.y] = ''
		}
	}

	view.buffer.auto_close_chars.clear()

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
		view.to   -= diff
		if view.from < 0 {
			view.from = 0
		}
		if view.to < 0 {
			view.to = 0
		}
		return
	}

	// FIX(tauraamui) [13/03/2025]: this is wrong, there's a heinous test checking the rendering
	//                              document behaviour, that's indicating that somehow we're
	//                              enabling from to become unpinned from the "bottom" of the document
	//                              viewport...
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
	if view.buffer.lines.len == 0 { return 0 }
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
	view.cmd_buf.clear_err()
	view.cmd_buf.line = "//"
	view.cmd_buf.cursor_x = 1
	view.search.prepare_for_input()
}

fn (mut view View) f(e draw.Event) {
	view.leader_state.f_count += 1
	if view.leader_state.f_count == 1 { view.leader_state.mode = .pending_f return }
	if view.leader_state.f_count == 2 {
		cursor_pos := view.cursor.pos.x
		line := view.buffer.lines[view.cursor.pos.y]
		if line.len == 0 { return }
		line_runes := line.runes()
		remaining_line := line_runes[cursor_pos..line_runes.len].string()

		for i, c in remaining_line {
			if e.ascii == c {
				// this "+ 2" is so that we jump one character past the match
				// so that we can jump forward again using the f command
				view.cursor.pos.x = cursor_pos + i + 2
				break
			}
		}
		view.clamp_cursor_within_document_bounds()
		view.leader_state.reset()
		view.escape()
		return
	}
}

fn (mut view View) g() {
	repeat_amount := strconv.atoi(view.chord.pending_repeat_amount()) or { 0 }
	view.leader_state.g_count += 1
	if view.leader_state.g_count == 1 { view.leader_state.mode = .pending_g }
	if view.leader_state.g_count == 2 {
		if repeat_amount > 0 {
			view.jump_cursor_to(repeat_amount - 1)
			view.chord.reset()
		} else {
			view.jump_cursor_to(0)
		}
		view.leader_state.reset()
	}
	view.clamp_cursor_x_pos()
}

fn (mut view View) shift_g() {
	repeat_amount := strconv.atoi(view.chord.pending_repeat_amount()) or { 0 }
	if repeat_amount > 0 {
		view.jump_cursor_to(repeat_amount - 1)
		view.chord.reset()
	} else {
		view.jump_cursor_to(view.buffer.lines.len - 1)
	}
	view.clamp_cursor_x_pos()
}

fn (mut view View) h() {
	view.left()
}

fn (mut view View) shift_h() {
	view.clamp_cursor_x_pos()
	view.jump_cursor_to(view.from)
}

fn (mut view View) l() {
	view.right()
}

fn (mut view View) shift_l() {
	view.jump_cursor_to(view.to - 1)
	view.clamp_cursor_x_pos()
}

fn (mut view View) shift_m() {
	view.jump_cursor_to((view.to - view.from) / 2)
	view.clamp_cursor_x_pos()
}

fn (mut view View) j() {
	view.down()
}

fn (mut view View) k() {
	view.up()
}

fn (mut view View) i() {
	view.leader_state.mode = .insert
	view.buffer.move_cursor_to(buffer.Pos{ x: view.cursor.pos.x, y: view.cursor.pos.y })
	if view.buffer.use_gap_buffer { return }
	view.clamp_cursor_x_pos()
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

fn (mut view View) x() {
	pos := view.buffer.x(buffer.Pos{ x: view.cursor.pos.x, y: view.cursor.pos.y }) or { return }
	view.cursor.pos.x = pos.x
	view.cursor.pos.y = pos.y
}

/*
fn (mut view View) copy_lines_into_clipboard(start int, end int) {
	assert start >= 0
	assert end >= 0
	assert end + 1 <= view.buffer.lines.len
	view.clipboard.copy(arrays.join_to_string(view.buffer.lines[start..end + 1].clone(),
		'\n', fn (s string) string {
		return s
	}))
}
*/

fn (mut view View) visual_d(overwrite_y_lines bool) {}

fn (mut view View) visual_line_d(overwrite_y_lines bool) {
	defer { view.clamp_cursor_within_document_bounds() }
	mut start := view.cursor.selection_start().y
	mut end := view.cursor.selection_end().y

	// view.copy_lines_into_clipboard(start, end)
	before := view.buffer.lines[..start]
	after := view.buffer.lines[end + 1..]

	view.buffer.lines = before
	view.buffer.lines << after
	view.cursor.pos.y = start
	view.escape()
}

fn (mut view View) w() {
	if view.buffer.use_gap_buffer {
		pos := view.buffer.find_next_word_start(buffer.Pos{ x: view.cursor.pos.x, y: view.cursor.pos.y }) or { return }
		view.cursor.pos.x = pos.x
		view.cursor.pos.y = pos.y
		view.scroll_from_and_to()
		return
	}
	defer { view.clamp_cursor_x_pos() }
	mut line := view.buffer.lines[view.cursor.pos.y]
	mut amount := calc_w_move_amount(view.cursor.pos, line, false)
	if amount == 0 {
		view.move_cursor_down(1)
		view.cursor.pos.x = 0

		if view.cursor.pos.y < view.buffer.lines.len {
			line = view.buffer.lines[view.cursor.pos.y]
			if line.len > 0 && is_whitespace(line[view.cursor.pos.x]) {
				amount = calc_w_move_amount(view.cursor.pos, line, false)
				assert amount >= 0
			}
		}
	}
	view.cursor.pos.x += amount
}

fn (mut view View) e() {
	if view.buffer.use_gap_buffer {
		pos := view.buffer.find_next_word_end(buffer.Pos{ x: view.cursor.pos.x, y: view.cursor.pos.y }) or { return }
		view.cursor.pos.x = pos.x
		view.cursor.pos.y = pos.y
		view.scroll_from_and_to()
		return
	}
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
	if view.buffer.use_gap_buffer {
		pos := view.buffer.find_prev_word_start(buffer.Pos{ x: view.cursor.pos.x, y: view.cursor.pos.y }) or { return }
		view.cursor.pos.x = pos.x
		view.cursor.pos.y = pos.y
		view.scroll_from_and_to()
		return
	}
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
	defer { view.clamp_cursor_x_pos() }
	line := view.buffer.lines[view.cursor.pos.y]
	if line.len == 0 { return }

	mut pos := 0
	line_chars := line.runes()
	for is_whitespace(line_chars[pos]) {
		pos += 1
		if !is_whitespace(line_chars[pos]) {
			view.cursor.pos.x = pos
			return
		}
	}
	view.cursor.pos.x = pos
}

fn (mut view View) zero() {
	view.cursor.pos.x = 0
}

fn (mut view View) dollar() {
	defer { view.clamp_cursor_x_pos() }
	line := view.buffer.lines[view.cursor.pos.y]
	view.cursor.pos.x = line.runes().len - 1
}

fn (mut view View) d() {
	match view.leader_state.mode {
		.normal {
			view.leader_state.d_count += 1
			if view.leader_state.d_count == 1 {
				view.leader_state.mode = .pending_delete
			}
		}
		.pending_delete {
			view.leader_state.d_count += 1
			if view.leader_state.d_count >= 2 {
				index := if view.cursor.pos.y == view.buffer.lines.len { view.cursor.pos.y - 1 } else { view.cursor.pos.y }
				view.clipboard.set_content(clipboardv2.ClipboardContent{
					type: .block,
					data: view.buffer.lines[index]
				})
				view.delete_line(index)
				view.clamp_cursor_within_document_bounds()
				view.leader_state.reset()
			}
		}
		.visual_line {
			start_index := view.cursor.selection_start().y
			mut end_index := view.cursor.selection_end().y
			view.clipboard.set_content(clipboardv2.ClipboardContent{
				type: .block,
				data: view.buffer.lines[start_index..end_index + 1].join("\n")
			})
			view.delete_line_range(start_index, end_index)
			view.cursor.pos.y = start_index
			view.clamp_cursor_within_document_bounds()
			view.leader_state.reset()
		}
		else {}
	}
}

fn (mut view View) p() {
	insert_below := match view.leader_state.mode {
		.normal { true }
		else { false }
	}
	content := view.clipboard.get_content()
	match content.type {
		.none { return }
		.inline {
			content_data_array := content.data.split("\n")
			if content_data_array.len == 1 {
				pre_cursor := view.buffer.lines[view.cursor.pos.y][..view.cursor.pos.x + 1]
				post_cursor := view.buffer.lines[view.cursor.pos.y][view.cursor.pos.x + 1..]
				view.buffer.lines[view.cursor.pos.y] = pre_cursor + content_data_array[0] + post_cursor
				view.cursor.pos.x += content_data_array[0].runes().len
				return
			}
		}
		.block {
			if insert_below {
				view.buffer.lines.insert(view.cursor.pos.y + 1, content.data.split("\n"))
				view.j()
				view.hat()
			}
		}
	}
}

fn (mut view View) delete_line(y int) {
	view.delete_line_range(y, y)
}

fn (mut view View) delete_line_range(start int, end int) {
	if start == end {
		view.buffer.lines.delete(start)
		return
	}
	before := view.buffer.lines[..start]
	after  := view.buffer.lines[end + 1..]

	view.buffer.lines = before
	view.buffer.lines << after
}

/*
fn (mut view View) d() {
	view.leader_state.d_count += 1
	if view.leader_state.d_count == 1 {
		view.leader_state.mode = .pending_delete
	}
	if view.leader_state.d_count == 2 {
		index := if view.cursor.pos.y == view.buffer.lines.len { view.cursor.pos.y - 1 } else { view.cursor.pos.y }
		view.clipboard.set_content(clipboardv2.ClipboardContent{
			type: .block,
			data: view.buffer.lines[index]
		})
		// view.copy_lines_into_clipboard(index, index)
		view.buffer.lines.delete(index)
		view.leader_state.d_count = 0
		view.clamp_cursor_within_document_bounds()
		view.leader_state.mode = .normal
	}
}
*/

fn (mut view View) z() {
	view.leader_state.z_count += 1
	if view.leader_state.z_count == 1 { view.leader_state.mode = .pending_z }
	if view.leader_state.z_count == 2 {
		view.center_text_around_cursor()
		view.leader_state.reset()
	}
}

// TODO(tauraamui) [07/03/2025]: I have no idea how this code works, should probably ask Kelly to remind me
fn (mut view View) center_text_around_cursor() {
	orig_cursor_pos := view.cursor.pos.y
	window_center_offset := int((view.to - view.from)/2)
	mut cursor_screen_pos := view.calc_cursor_y_in_screen_space()

	// With the following logic, a second zz action will not move the cursor
	if cursor_screen_pos < window_center_offset {
		view.jump_cursor_to(view.from)
		view.move_cursor_up(window_center_offset - cursor_screen_pos)
	} else if cursor_screen_pos > window_center_offset{
		cursor_screen_pos = cursor_screen_pos - window_center_offset - 2
		view.jump_cursor_to(view.to)
		view.move_cursor_down(cursor_screen_pos)
	}
	view.jump_cursor_to(orig_cursor_pos)
	view.clamp_cursor_within_document_bounds()
}

fn (mut view View) u() {}

fn (mut view View) o() {
	if view.buffer.use_gap_buffer {
		view.cursor.pos.x = view.buffer.find_end_of_line(buffer.Pos{ y: view.cursor.pos.y }) or { 0 }
		view.i()
		view.insert_text(buffer.lf.str())
		view.scroll_from_and_to()
		return
	}
	view.leader_state.mode = .insert
	defer { view.move_cursor_down(1) }
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
	if view.buffer.use_gap_buffer {
		view.cursor.pos.x = 0
		view.i()
		view.insert_text(buffer.lf.str())
		view.cursor.pos.y -= 1
		view.scroll_from_and_to()
		return
	}
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

fn (mut view View) y() {
	match view.leader_state.mode {
		.visual {
			start := view.cursor.selection_start()
			end   := view.cursor.selection_end()
			if start.y == end.y {
				view.clipboard.set_content(clipboardv2.ClipboardContent{
					type: .inline,
					data: view.buffer.lines[start.y][start.x..end.x + 1]
				})
				return
			}
			mut copied_line_contents := []string{}
			selection_line_span := end.y - start.y
			copied_line_contents << view.buffer.lines[start.y][view.cursor.pos.x + 1..]

			for i in 1..selection_line_span {
				copied_line_contents << view.buffer.lines[start.y + i]
			}
			copied_line_contents << view.buffer.lines[end.y][..view.cursor.pos.x + 1]
			view.clipboard.set_content(clipboardv2.ClipboardContent{
				type: .inline,
				data: copied_line_contents.join("\n")
			})
		}
		.visual_line {
			start_index   := view.cursor.selection_start().y
			mut end_index := view.cursor.selection_end().y
			view.clipboard.set_content(clipboardv2.ClipboardContent{
				type: .block,
				data: view.buffer.lines[start_index..end_index + 1].join("\n")
			})
			view.cursor.pos.y = start_index
			view.clamp_cursor_within_document_bounds()
			view.leader_state.reset()
		}
		else {}
	}
}

fn (mut view View) enter() {
	pos := view.buffer.enter(buffer.Pos{ x: view.cursor.pos.x, y: view.cursor.pos.y }) or { return }
	view.cursor.pos.x = pos.x
	view.cursor.pos.y = pos.y
	view.scroll_from_and_to()
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
	pos := view.buffer.backspace(buffer.Pos{ x: view.cursor.pos.x, y: view.cursor.pos.y }) or { return }
	view.cursor.pos.x = pos.x
	view.cursor.pos.y = pos.y
	view.scroll_from_and_to()
	return
}

fn (mut view View) left() {
	pos := view.buffer.left(buffer.Pos{ x: view.cursor.pos.x, y: view.cursor.pos.y }, view.leader_state.mode == .insert) or { return }
	view.cursor.pos.x = pos.x
	view.cursor.pos.y = pos.y
}

fn (mut view View) right() {
	pos := view.buffer.right(buffer.Pos{ x: view.cursor.pos.x, y: view.cursor.pos.y }, view.leader_state.mode == .insert) or { return }
	view.cursor.pos.x = pos.x
	view.cursor.pos.y = pos.y
}

fn (mut view View) down() {
	pos := view.buffer.down(buffer.Pos{ x: view.cursor.pos.x, y: view.cursor.pos.y }, view.leader_state.mode == .insert) or { return }
	view.cursor.pos.x = pos.x
	view.cursor.pos.y = pos.y
	view.scroll_from_and_to()
}

fn (mut view View) up() {
	pos := view.buffer.up(buffer.Pos{ x: view.cursor.pos.x, y: view.cursor.pos.y }, view.leader_state.mode == .insert) or { return }
	view.cursor.pos.x = pos.x
	view.cursor.pos.y = pos.y
	view.scroll_from_and_to()
}

fn (mut view View) scroll_up() {
	view.move_cursor_down(1)
}

fn (mut view View) scroll_down() {
	view.up()
}

fn (mut view View) on_mouse_scroll(e draw.Event) {
	if e.y <= 0 || e.y > view.height - 2 { return }
	match e.direction {
		.up   { view.scroll_up() }
		.down { view.scroll_down() }
		else {}
	}
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
	// We have to check for the underscore here because is_non_alpha includes
	// underscores for large number digit separation!
	if r == `_` {
		return r
	}
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
	pos := view.buffer.up_to_next_blank_line(buffer.Pos{ x: view.cursor.pos.x, y: view.cursor.pos.y }) or { return }
	view.cursor.pos.x = pos.x
	view.cursor.pos.y = pos.y
	view.scroll_from_and_to()
}

fn (mut view View) jump_cursor_down_to_next_blank_line() {
	pos := view.buffer.down_to_next_blank_line(buffer.Pos{ x: view.cursor.pos.x, y: view.cursor.pos.y }) or { return }
	view.cursor.pos.x = pos.x
	view.cursor.pos.y = pos.y
	view.scroll_from_and_to()
}

fn (mut view View) left_square_bracket() {
	view.right_bracket_press_count = 0
	view.left_bracket_press_count += 1

	if view.left_bracket_press_count >= 2 {
		view.cursor.pos.y = 0
		view.scroll_from_and_to()
		view.left_bracket_press_count = 0
	}
}

fn (mut view View) right_square_bracket() {
	view.left_bracket_press_count = 0
	view.right_bracket_press_count += 1

	if view.right_bracket_press_count >= 2 {
		view.cursor.pos.y = view.buffer.lines.len - 1
		view.scroll_from_and_to()
		view.right_bracket_press_count = 0
	}
}

fn (mut view View) replace_char(code u8, str string) {
	view.buffer.replace_char(buffer.Pos{ x: view.cursor.pos.x, y: view.cursor.pos.y }, code, str)
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
