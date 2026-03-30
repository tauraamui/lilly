// Copyright 2026 The Lilly Edtior contributors
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

import tauraamui.bobatea as tea
import lib.petal.theme
import lib.petal
import palette
import lib.documents
import lib.documents.cursor
import lib.syntax
import lib.clipboard

pub const tab_width = 4

fn num_digits(n int) int {
	if n <= 0 { return 1 }
	mut count := 0
	mut v := n
	for v > 0 {
		count++
		v /= 10
	}
	return count
}

struct EditorData {
	id            int
	file_path     string
	cursor_row    int
	cursor_col    int
	chord_display string
}

struct EditorModel {
	id     int
	doc_id int

	theme     theme.Theme
	file_path string
mut:
	focused        bool
	show_border    bool = true
	cursor_underline bool

	width  int
	height int
	min_y  int

	doc_controller &documents.Controller
	cb             &clipboard.Manager
	token_parser   syntax.Parser
	lang_syn       syntax.Syntax
	arena          Arena
	rune_buf       []rune

	sel_start_pos  ?cursor.Pos
	sel_mode       petal.Mode = .normal // tracks which visual mode (.visual or .visual_line)
	chord Chord
}

struct OpenEditorMsg {
	file_path string
}

fn open_editor(file_path string) tea.Cmd {
	return fn [file_path] () tea.Msg {
		return OpenEditorMsg{file_path}
	}
}

struct QueryEditorDataMsg {}

fn query_editor_data(id int) tea.Cmd {
	return fn [id] () tea.Msg {
		return EditorModelMsg{
			id:  id
			msg: QueryEditorDataMsg{}
		}
	}
}

struct EditorDataResultMsg {
	data EditorData
}

fn editor_data(data EditorData) tea.Cmd {
	return fn [data] () tea.Msg {
		return EditorDataResultMsg{data}
	}
}

struct WriteToDiskMsg {}

fn write_to_disk(id int) tea.Cmd {
	return fn [id] () tea.Msg {
		return EditorModelMsg{
			id: id
			msg: WriteToDiskMsg{}
		}
	}
}

@[params]
struct EditorModelNewParams {
	theme theme.Theme
	id int
	file_path string
	doc_id int
	doc_controller &documents.Controller
	cb             &clipboard.Manager
}

fn EditorModel.new(opts EditorModelNewParams) EditorModel {
	assert opts.file_path != ''
	return EditorModel{
		id:             opts.id
		file_path:      opts.file_path
		doc_id:         opts.doc_id
		theme:          opts.theme
		doc_controller: opts.doc_controller
		cb:             opts.cb
		token_parser:   syntax.Parser{}
		lang_syn:       syntax.v_syntax() or { panic('unable to resolve v language syntax') }
	}
}

fn (mut m EditorModel) init() ?tea.Cmd {
	return tea.emit_resize
}

struct EditorModelMsg {
	id   int
	msg  tea.Msg
	mode petal.Mode
}

struct EditorModelKeyMsg {
	key_msg tea.KeyMsg
	mode    petal.Mode
}

fn (mut m EditorModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	mut cmds := []tea.Cmd{}

	if msg is EditorModelKeyMsg && m.focused {
		match msg.mode {
			.insert {
				match msg.key_msg.k_type {
					.runes {
						for cr in msg.key_msg.string().runes_iterator() {
							m.doc_controller.insert_char(m.doc_id, cr)
						}
					}
					.special {
						match msg.key_msg.string() {
							'enter' {
								leading_whitespace := m.doc_controller.leading_whitespace_on_current_line(m.doc_id)
								m.doc_controller.insert_newline(m.doc_id)
								for cr in leading_whitespace {
									m.doc_controller.insert_char(m.doc_id, cr)
								}
							}
							'backspace' { m.doc_controller.backspace(m.doc_id) }
							'delete' { m.doc_controller.delete(m.doc_id) }
							'ctrl+i' { m.doc_controller.insert_char(m.doc_id, `\t`) } // ctrl+i is apparently equiv to TAB
							'left' {
								m.doc_controller.move_cursor_left(m.doc_id, .insert)
								m.doc_controller.prepare_for_insertion(m.doc_id) or {
									cmds << raise_error('error: ${err}')
									m.ensure_cursor_visible()
									return m.clone(), tea.batch_array(cmds)
								}
							}
							'up' {
								m.doc_controller.move_cursor_up(m.doc_id, .insert)
								m.doc_controller.prepare_for_insertion(m.doc_id) or {
									cmds << raise_error('error: ${err}')
									m.ensure_cursor_visible()
									return m.clone(), tea.batch_array(cmds)
								}
							}
							'right' {
								m.doc_controller.move_cursor_right(m.doc_id, .insert)
								m.doc_controller.prepare_for_insertion(m.doc_id) or {
									cmds << raise_error('error: ${err}')
									m.ensure_cursor_visible()
									return m.clone(), tea.batch_array(cmds)
								}
							}
							'down' {
								m.doc_controller.move_cursor_down(m.doc_id, .insert)
								m.doc_controller.prepare_for_insertion(m.doc_id) or {
									cmds << raise_error('error: ${err}')
									m.ensure_cursor_visible()
									return m.clone(), tea.batch_array(cmds)
								}
							}
							else {}
						}
					}
				}
			}
			.visual {
				match msg.key_msg.k_type {
					.special {
						match msg.key_msg.string() {
							'escape' { cmds << switch_mode(.normal) }
							'left' { m.doc_controller.move_cursor_left(m.doc_id, .visual) }
							'right' { m.doc_controller.move_cursor_right(m.doc_id, .visual) }
							'up' { m.doc_controller.move_cursor_up(m.doc_id, .visual) }
							'down' { m.doc_controller.move_cursor_down(m.doc_id, .visual) }
							else {}
						}
					}
					.runes {
						match msg.key_msg.string() {
							'h' { m.doc_controller.move_cursor_left(m.doc_id, .visual) }
							'l' { m.doc_controller.move_cursor_right(m.doc_id, .visual) }
							'k' { m.doc_controller.move_cursor_up(m.doc_id, .visual) }
							'j' { m.doc_controller.move_cursor_down(m.doc_id, .visual) }
							'w' { m.doc_controller.move_cursor_to_next_word_start(m.doc_id) }
							'W' { m.doc_controller.move_cursor_to_next_big_word_start(m.doc_id) }
							'e' { m.doc_controller.move_cursor_to_next_word_end(m.doc_id) }
							'b' { m.doc_controller.move_cursor_to_previous_word_start(m.doc_id) }
							'$' { m.doc_controller.move_cursor_to_line_end(m.doc_id, .normal) }
							'd' {
								if sel_start := m.sel_start_pos {
									m.yank_visual_selection(sel_start)
									m.doc_controller.delete_visual_range(m.doc_id, cursor.Range{
										start: sel_start
										end:   m.doc_controller.cursor_pos(m.doc_id)
									})
									cmds << switch_mode(.normal)
								}
							}
							'y' {
								if sel_start := m.sel_start_pos {
									m.yank_visual_selection(sel_start)
									cmds << switch_mode(.normal)
								}
							}
							else {}
						}
					}
				}
			}
			.visual_line {
				match msg.key_msg.k_type {
					.special {
						match msg.key_msg.string() {
							'escape' { cmds << switch_mode(.normal) }
							'up' { m.doc_controller.move_cursor_up(m.doc_id, .visual_line) }
							'down' { m.doc_controller.move_cursor_down(m.doc_id, .visual_line) }
							'k' { m.doc_controller.move_cursor_up(m.doc_id, .visual_line) }
							'j' { m.doc_controller.move_cursor_down(m.doc_id, .visual_line) }
							else {}
						}
					}
					.runes {
						match msg.key_msg.string() {
							'k' { m.doc_controller.move_cursor_up(m.doc_id, .visual_line) }
							'j' { m.doc_controller.move_cursor_down(m.doc_id, .visual_line) }
							'{' { m.doc_controller.move_cursor_to_previous_blank_line(m.doc_id) }
							'}' { m.doc_controller.move_cursor_to_next_blank_line(m.doc_id) }
							'd' {
								if sel_start := m.sel_start_pos {
									m.yank_visual_line_selection(sel_start)
									m.doc_controller.delete_range(m.doc_id, cursor.Range{
										start: sel_start
										end:   m.doc_controller.cursor_pos(m.doc_id)
									})
									cmds << switch_mode(.normal)
								}
							}
							'y' {
								if sel_start := m.sel_start_pos {
									m.yank_visual_line_selection(sel_start)
									cmds << switch_mode(.normal)
								}
							}
							else {}
						}
					}
				}
			}
			.normal {
				match msg.key_msg.k_type {
					.runes {
						cmds << editor_data(m.data())
						if action := m.chord.feed(msg.key_msg.string()) {
							m.execute_action(action, mut cmds)
						}
					}
					.special {
						match msg.key_msg.string() {
							'escape' {
								m.chord.reset()
								cmds << editor_data(m.data())
							}
							'ctrl+u' {
								half := m.height / 2
								m.min_y -= half
								if m.min_y < 0 {
									m.min_y = 0
								}
								target_y := m.min_y + m.height / 4
								current_y := m.doc_controller.cursor_pos(m.doc_id).y
								if current_y > target_y {
									m.doc_controller.move_cursor_up_by(m.doc_id, current_y - target_y, .normal)
								} else {
									m.doc_controller.move_cursor_down_by(m.doc_id, target_y - current_y, .normal)
								}
								m.ensure_cursor_visible()
							}
							'ctrl+d' {
								half := m.height / 2
								m.min_y += half
								target_y := m.min_y + m.height * 3 / 4
								current_y := m.doc_controller.cursor_pos(m.doc_id).y
								if current_y < target_y {
									m.doc_controller.move_cursor_down_by(m.doc_id, target_y - current_y, .normal)
								} else {
									m.doc_controller.move_cursor_up_by(m.doc_id, current_y - target_y, .normal)
								}
								m.ensure_cursor_visible()
							}
							'delete' {
								m.doc_controller.prepare_for_insertion(m.doc_id) or {
									cmds << raise_error('error: ${err}')
									m.ensure_cursor_visible()
									return m.clone(), tea.batch_array(cmds)
								}
								m.doc_controller.delete(m.doc_id)
							}
							'left' {
								m.doc_controller.move_cursor_left(m.doc_id, .normal)
							}
							'up' {
								m.doc_controller.move_cursor_up(m.doc_id, .normal)
							}
							'right' {
								m.doc_controller.move_cursor_right(m.doc_id, .normal)
							}
							'down' {
								m.doc_controller.move_cursor_down(m.doc_id, .normal)
							}
							else {}
						}
					}
				}
			}
			else {}
		}
	}

	match msg {
		tea.ResizedMsg {
			m.width = msg.window_width
			m.height = msg.window_height
		}
		SwitchModeMsg {
			if !m.focused { return m.clone(), none }
			match msg.mode {
				.insert {
					m.doc_controller.prepare_for_insertion(m.doc_id) or {
						cmds << raise_error('switch mode error: ${err}')
						return m.clone(), tea.batch_array(cmds)
					}
				}
				.normal {
					// if msg.from != .command && msg.from != .pending_delete && msg.from != .pending_g {
					if msg.from == .normal || msg.from == .insert {
						current_line := m.doc_controller.get_line_at(m.doc_id, m.doc_controller.cursor_pos(m.doc_id).y) or { '' }
						if current_line.len > 0 && current_line.trim_space().len == 0 {
							m.doc_controller.clear_line(m.doc_id)
						} else {
							m.doc_controller.move_cursor_left(m.doc_id, .normal)
						}
					}
					m.sel_start_pos = ?cursor.Pos(none)
					m.sel_mode = .normal
				}
				.visual {
					m.sel_start_pos = m.doc_controller.cursor_pos(m.doc_id)
					m.sel_mode = .visual
				}
				.visual_line {
					m.sel_start_pos = m.doc_controller.cursor_pos(m.doc_id)
					m.sel_mode = .visual_line
				}
				else {}
			}
		}
		EditorModelMsg {
			match msg.msg {
				tea.FocusedMsg {
					m.focused = msg.id == m.id
				}
				tea.BlurredMsg {
					if msg.id == m.id {
						m.focused = false
					}
				}
				QueryEditorDataMsg {
					if msg.id == m.id {
						cmds << editor_data(m.data())
					}
				}
				WriteToDiskMsg {
					if msg.id == m.id {
						m.doc_controller.write_document(m.doc_id) or {
							cmds << raise_error('failed to write to disk')
							m.ensure_cursor_visible()
							return m.clone(), tea.batch_array(cmds)
						}
						message_text := 'written to disk successfully'
						cmds << tea.sequence(debug_log(message_text), display_message(.normal, message_text))
					}
					m.ensure_cursor_visible()
					return m.clone(), tea.batch_array(cmds)
				}
				else {}
			}
		}
		ToggleEditorShowBorderMsg {
			if msg.id == m.id {
				m.show_border = msg.show
			} else {
				if msg.show == false {
					m.show_border = true
				}
			}
		}
		else {}
	}
	m.ensure_cursor_visible()
	return m.clone(), tea.batch_array(cmds)
}

const active_editor_border_color = palette.petal_pink_color
const inactive_editor_border_color = palette.status_dark_lilac

fn (mut m EditorModel) view(mut ctx tea.Context) {
	ctx.set_clip_area(tea.ClipArea{0, 0, m.width, m.height})
	defer { ctx.clear_clip_area() }

	if m.show_border {
		border_color := if m.focused {
			active_editor_border_color
		} else {
			inactive_editor_border_color
		}
		ctx.set_color(border_color)
		for y in 0 .. m.height {
			ctx.draw_text(0, y, '│')
		}
		ctx.reset_color()
		ctx.push_offset(tea.Offset{ x: 1 })
	}

	if m.arena.buf == unsafe { nil } {
		m.arena = Arena.new(512 * 1024)
	}
	m.arena.reset()
	m.token_parser.reset()

	// compute fixed gutter width based on the largest visible line number (1-based)
	max_line_nr := m.min_y + m.height
	gutter_width := num_digits(max_line_nr) + 1 // +1 for padding after the number

	// push gutter offset so selections, cursor highlight, and cursor are all shifted right
	ctx.push_offset(tea.Offset{ x: gutter_width })

	cursor_vpos := m.doc_controller.visual_cursor_pos(m.doc_id, tab_width)
	if sel_start := m.sel_start_pos {
		if m.sel_mode == .visual {
			sel_start_vpos := m.doc_controller.visual_pos_for(m.doc_id, sel_start, tab_width)
			m.render_visual_selection(mut ctx, sel_start_vpos, cursor_vpos)
		} else {
			m.render_visual_line_selection(mut ctx, sel_start.y, cursor_vpos.y)
		}
	} else {
		m.render_cursor_line_highlight(mut ctx, cursor_vpos.y)
	}

	for y, l in m.doc_controller.get_iterator(m.doc_id) {
		visible := y >= m.min_y && y < m.min_y + m.height
		if !visible {
			// still feed the parser for state tracking (block comments, strings spanning lines)
			m.token_parser.parse_line(y, l.string())
			continue
		}
		// draw right-aligned line number in the gutter area (negative x to draw before the offset)
		line_nr := '${y + 1}'
		ctx.set_color(m.theme.syntax_comment)
		ctx.draw_text(-1 - line_nr.len, y - m.min_y, line_nr)
		ctx.reset_color()
		offset_id := ctx.push_offset(tea.Offset{ x: 0 })
		defer { ctx.clear_offsets_from(offset_id) }
		line_str := l.string()
		line_content := m.arena.expand_tabs(line_str, tab_width)
		line_tokens := m.token_parser.parse_line(y, line_content)
		// fill reusable rune buffer instead of allocating via .runes()
		m.rune_buf.clear()
		for r in line_content.runes_iterator() {
			m.rune_buf << r
		}
		for i, t in line_tokens {
			token_str := m.arena.runes_to_str(m.rune_buf, t.start(), t.end())
			match t.t_type() {
				.comment {
					ctx.set_color(m.theme.syntax_comment)
				}
				.string {
					ctx.set_color(m.theme.syntax_string)
				}
				.number {
					ctx.set_color(tea.Color.ansi(199))
				}
				else {
					match true {
						token_str in m.lang_syn.keywords {
							ctx.set_color(m.theme.petal_red)
						}
						token_str in m.lang_syn.literals {
							ctx.set_color(m.theme.syntax_literal)
						}
						token_str in m.lang_syn.builtins {
							ctx.set_color(m.theme.syntax_builtin)
						}
						else {}
					}
					prev_token := if i - 1 >= 0 { ?syntax.Token(line_tokens[i - 1]) } else { ?syntax.Token(none) }
					next_token := if i + 1 < line_tokens.len { ?syntax.Token(line_tokens[i + 1]) } else { ?syntax.Token(none) }

					if pt := prev_token {
						if pt.t_type() != .whitespace && pt.end() - pt.start() == 1 && m.rune_buf[pt.start()] == `_` { ctx.reset_color() }
					} else {
						if nt := next_token {
							if nt.t_type() != .whitespace && nt.end() - nt.start() == 1 && m.rune_buf[nt.start()] == `_` { ctx.reset_color() }
						}
					}

				}
			}
			ctx.draw_text(0, y - m.min_y, token_str)
			ctx.push_offset(tea.Offset{ x: utf8_str_visible_length(token_str) })
			ctx.reset_color()
		}
	}

	if m.focused {
		m.render_cursor(mut ctx)
	}
}

fn (m EditorModel) render_cursor_line_highlight(mut ctx tea.Context, cursor_pos_y int) {
	ctx.set_bg_color(m.theme.cursor_line_bg)
	defer { ctx.reset_bg_color() }
	ctx.draw_rect(0, cursor_pos_y - m.min_y, m.width, 1)
}

fn (m EditorModel) render_visual_line_selection(mut ctx tea.Context, sel_start_y int, cursor_y int) {
	start_y := if sel_start_y < cursor_y { sel_start_y } else { cursor_y }
	end_y := if sel_start_y > cursor_y { sel_start_y } else { cursor_y }
	ctx.set_bg_color(m.theme.highlight_bg_color)
	defer { ctx.reset_bg_color() }
	for y in start_y .. end_y + 1 {
		screen_y := y - m.min_y
		if screen_y >= 0 && screen_y < m.height {
			ctx.draw_rect(0, screen_y, m.width, 1)
		}
	}
}

fn (m EditorModel) render_visual_selection(mut ctx tea.Context, sel_start cursor.Pos, cursor_pos cursor.Pos) {
	// Normalize so start is before end
	start := if sel_start.y < cursor_pos.y || (sel_start.y == cursor_pos.y && sel_start.x <= cursor_pos.x) {
		sel_start
	} else {
		cursor_pos
	}
	end := if sel_start.y < cursor_pos.y || (sel_start.y == cursor_pos.y && sel_start.x <= cursor_pos.x) {
		cursor_pos
	} else {
		sel_start
	}

	ctx.set_bg_color(m.theme.highlight_bg_color)
	defer { ctx.reset_bg_color() }

	if start.y == end.y {
		// Single line selection
		screen_y := start.y - m.min_y
		if screen_y >= 0 && screen_y < m.height {
			ctx.draw_rect(start.x, screen_y, end.x - start.x + 1, 1)
		}
	} else {
		// Multi-line selection
		// First line: from start.x to end of line
		screen_y := start.y - m.min_y
		if screen_y >= 0 && screen_y < m.height {
			ctx.draw_rect(start.x, screen_y, m.width - start.x, 1)
		}
		// Middle lines: full width
		for y in start.y + 1 .. end.y {
			sy := y - m.min_y
			if sy >= 0 && sy < m.height {
				ctx.draw_rect(0, sy, m.width, 1)
			}
		}
		// Last line: from start to end.x
		last_sy := end.y - m.min_y
		if last_sy >= 0 && last_sy < m.height {
			ctx.draw_rect(0, last_sy, end.x + 1, 1)
		}
	}
}

fn (m EditorModel) render_cursor(mut ctx tea.Context) {
	cursor_pos := m.doc_controller.visual_cursor_pos(m.doc_id, tab_width)
	char_at := m.doc_controller.get_char_at(m.doc_id) or { ' ' }.expand_tabs(tab_width)
	if m.cursor_underline {
		default_fg_color := ctx.get_default_fg_color() or { palette.matte_white_fg_color }
		ctx.set_color(default_fg_color)
		ctx.set_style(.underline)
		ctx.draw_text(cursor_pos.x, cursor_pos.y - m.min_y, char_at)
		ctx.clear_style()
		ctx.reset_color()
	} else {
		// basically we want the block cursor to be the inverse of the background shade
		// and then the text/fg color to be the inverse of that/the same as background
		default_bg_color := ctx.get_default_bg_color() or { palette.matte_black_bg_color }
		ctx.set_bg_color(palette.fg_color(default_bg_color))
		ctx.set_color(default_bg_color)
		ctx.draw_text(cursor_pos.x, cursor_pos.y - m.min_y, char_at)
		ctx.reset_bg_color()
		ctx.reset_color()
	}
}

fn (mut m EditorModel) ensure_cursor_visible() {
	cursor_pos := m.doc_controller.cursor_pos(m.doc_id)
	if m.height <= 0 {
		return
	}
	if cursor_pos.y < m.min_y {
		m.min_y = cursor_pos.y
	} else if cursor_pos.y >= m.min_y + m.height {
		m.min_y = cursor_pos.y - m.height + 1
	}
}

fn (mut m EditorModel) execute_action(action ChordAction, mut cmds []tea.Cmd) {
	count := action.count

	if op := action.operator {
		match op {
			`d` {
				match action.motion {
					'line' {
						m.yank_lines(count)
						for _ in 0..count {
							m.doc_controller.delete_line(m.doc_id)
						}
					}
					'w' {
						// TODO(tauraamui)
						// delete word N times
					}
					else {}
				}
			}
			`y` {
				match action.motion {
					'line' {
						m.yank_lines(count)
					}
					else {}
				}
			}
			else {}
		}
	} else {
		// pure motion - no operator
		match action.motion {
			'o' {
				m.doc_controller.move_cursor_to_line_end(m.doc_id, .insert)
				m.doc_controller.prepare_for_insertion(m.doc_id) or {
					cmds << raise_error('error: ${err}')
					m.ensure_cursor_visible()
					return
				}
				leading_whitespace := m.doc_controller.leading_whitespace_on_current_line(m.doc_id)
				m.doc_controller.insert_newline(m.doc_id)
				for cr in leading_whitespace {
					m.doc_controller.insert_char(m.doc_id, cr)
				}
				cmds << switch_mode(.insert)
				m.ensure_cursor_visible()
			}
			'w' {
				for _ in 0..count {
					m.doc_controller.move_cursor_to_next_word_start(m.doc_id)
				}
			}
			'W' {
				for _ in 0..count {
					m.doc_controller.move_cursor_to_next_big_word_start(m.doc_id)
				}
			}
			'e' {
				for _ in 0..count {
					m.doc_controller.move_cursor_to_next_word_end(m.doc_id)
				}
			}
			'b' {
				for _ in 0..count {
					m.doc_controller.move_cursor_to_previous_word_start(m.doc_id)
				}
			}
			'ge' {
				for _ in 0..count {
					m.doc_controller.move_cursor_to_previous_word_end(m.doc_id)
				}
			}
			'h' {
				for _ in 0..count {
					m.doc_controller.move_cursor_left(m.doc_id, .normal)
				}
			}
			'j' {
				m.doc_controller.move_cursor_down_by(m.doc_id, count, .normal)
			}
			'k' {
				m.doc_controller.move_cursor_up_by(m.doc_id, count, .normal)
			}
			'l' {
				m.doc_controller.move_cursor_right(m.doc_id, .normal)
			}
			'$' {
				m.doc_controller.move_cursor_to_line_end(m.doc_id, .normal)
			}
			'0' {
				// m.doc_controller.move_cursor_to_line_start(m.doc_id)
			}
			'{' {
				for _ in 0..count {
					m.doc_controller.move_cursor_to_previous_blank_line(m.doc_id)
				}
			}
			'}' {
				for _ in 0..count {
					m.doc_controller.move_cursor_to_next_blank_line(m.doc_id)
				}
			}
			'x' {
				for _ in 0..count {
					m.doc_controller.delete_char_at(m.doc_id)
				}
			}
			'gg' {
				target := if action.count > 1 { action.count - 1 } else { 0 }
				current_y := m.doc_controller.cursor_pos(m.doc_id).y
				if current_y > target {
					m.doc_controller.move_cursor_up_by(m.doc_id, current_y - target, .normal)
				} else if current_y < target {
					m.doc_controller.move_cursor_down_by(m.doc_id, target - current_y, .normal)
				}
			}
			'G' {
				current_y := m.doc_controller.cursor_pos(m.doc_id).y
				last_line := m.doc_controller.line_count(m.doc_id) - 1
				if current_y < last_line {
					m.doc_controller.move_cursor_down_by(m.doc_id, last_line - current_y, .normal)
				}
			}
			'v' {
				cmds << switch_mode(.visual)
			}
			'V' {
				cmds << switch_mode(.visual_line)
			}
			'p' {
				m.paste_after()
			}
			'P' {
				m.paste_before()
			}
			else {}
		}
	}
}

fn (mut m EditorModel) yank_visual_line_selection(sel_start cursor.Pos) {
	current_pos := m.doc_controller.cursor_pos(m.doc_id)
	start_y := if sel_start.y < current_pos.y { sel_start.y } else { current_pos.y }
	end_y := if sel_start.y > current_pos.y { sel_start.y } else { current_pos.y }
	mut lines := []string{}
	for y in start_y .. end_y + 1 {
		if line := m.doc_controller.get_line_at(m.doc_id, y) {
			lines << line
		}
	}
	if lines.len > 0 {
		m.cb.set_content(clipboard.ClipboardContent{
			data: lines.join('\n')
			@type: .block
		})
	}
}

fn (mut m EditorModel) yank_visual_selection(sel_start cursor.Pos) {
	current_pos := m.doc_controller.cursor_pos(m.doc_id)
	// Normalize so start is before end
	start := if sel_start.y < current_pos.y || (sel_start.y == current_pos.y && sel_start.x <= current_pos.x) {
		sel_start
	} else {
		current_pos
	}
	end := if sel_start.y < current_pos.y || (sel_start.y == current_pos.y && sel_start.x <= current_pos.x) {
		current_pos
	} else {
		sel_start
	}

	if start.y == end.y {
		// Single line: extract substring
		if line := m.doc_controller.get_line_at(m.doc_id, start.y) {
			runes := line.runes()
			end_x := if end.x < runes.len { end.x } else { runes.len - 1 }
			if start.x <= end_x {
				m.cb.set_content(clipboard.ClipboardContent{
					data: runes[start.x .. end_x + 1].string()
					@type: .inline
				})
			}
		}
	} else {
		// Multi-line: rest of first line + middle lines + start of last line
		mut parts := []string{}
		if first_line := m.doc_controller.get_line_at(m.doc_id, start.y) {
			runes := first_line.runes()
			parts << runes[start.x ..].string()
		}
		for y in start.y + 1 .. end.y {
			if mid_line := m.doc_controller.get_line_at(m.doc_id, y) {
				parts << mid_line
			}
		}
		if last_line := m.doc_controller.get_line_at(m.doc_id, end.y) {
			runes := last_line.runes()
			end_x := if end.x < runes.len { end.x } else { runes.len - 1 }
			parts << runes[.. end_x + 1].string()
		}
		if parts.len > 0 {
			m.cb.set_content(clipboard.ClipboardContent{
				data: parts.join('\n')
				@type: .inline
			})
		}
	}
}

fn (mut m EditorModel) yank_lines(count int) {
	cursor_pos := m.doc_controller.cursor_pos(m.doc_id)
	mut lines := []string{}
	for i in 0 .. count {
		if line := m.doc_controller.get_line_at(m.doc_id, cursor_pos.y + i) {
			lines << line
		}
	}
	if lines.len > 0 {
		m.cb.set_content(clipboard.ClipboardContent{
			data: lines.join('\n')
			@type: .block
		})
	}
}

fn (mut m EditorModel) paste_after() {
	content := m.cb.get_content() or { return }
	if content.data.len == 0 { return }

	match content.@type {
		.block {
			// Block paste: insert as new lines below current line
			cursor_pos := m.doc_controller.cursor_pos(m.doc_id)
			m.doc_controller.move_cursor_to_line_end(m.doc_id, .insert)
			m.doc_controller.prepare_for_insertion(m.doc_id) or { return }
			for line in content.data.split('\n') {
				m.doc_controller.insert_newline(m.doc_id)
				for cr in line.runes() {
					m.doc_controller.insert_char(m.doc_id, cr)
				}
			}
			// Move cursor to start of first pasted line
			m.doc_controller.move_cursor_down_by(m.doc_id, 1, .normal)
			_ = cursor_pos // suppress unused warning
		}
		.inline {
			// Inline paste: insert text after cursor
			m.doc_controller.move_cursor_right(m.doc_id, .insert)
			start_pos := m.doc_controller.cursor_pos(m.doc_id)
			m.doc_controller.prepare_for_insertion(m.doc_id) or { return }
			mut newline_count := 0
			mut last_line_char_count := 0
			for cr in content.data.runes() {
				if cr == `\n` {
					m.doc_controller.insert_newline(m.doc_id)
					newline_count += 1
					last_line_char_count = 0
				} else {
					m.doc_controller.insert_char(m.doc_id, cr)
					last_line_char_count += 1
				}
			}
			// Reposition cursor on last character of pasted text
			if newline_count > 0 {
				final_x := if last_line_char_count > 0 { last_line_char_count - 1 } else { 0 }
				final_y := start_pos.y + newline_count
				m.doc_controller.set_cursor_pos(m.doc_id, cursor.Pos.new(final_x, final_y))
			} else if last_line_char_count > 0 {
				// Single-line paste: cursor on last pasted character
				final_x := start_pos.x + last_line_char_count - 1
				m.doc_controller.set_cursor_pos(m.doc_id, cursor.Pos.new(final_x, start_pos.y))
			}
		}
		.none {
			// Treat unknown as inline
			m.doc_controller.move_cursor_right(m.doc_id, .insert)
			start_pos := m.doc_controller.cursor_pos(m.doc_id)
			m.doc_controller.prepare_for_insertion(m.doc_id) or { return }
			mut newline_count := 0
			mut last_line_char_count := 0
			for cr in content.data.runes() {
				if cr == `\n` {
					m.doc_controller.insert_newline(m.doc_id)
					newline_count += 1
					last_line_char_count = 0
				} else {
					m.doc_controller.insert_char(m.doc_id, cr)
					last_line_char_count += 1
				}
			}
			// Reposition cursor on last character of pasted text
			if newline_count > 0 {
				final_x := if last_line_char_count > 0 { last_line_char_count - 1 } else { 0 }
				final_y := start_pos.y + newline_count
				m.doc_controller.set_cursor_pos(m.doc_id, cursor.Pos.new(final_x, final_y))
			} else if last_line_char_count > 0 {
				final_x := start_pos.x + last_line_char_count - 1
				m.doc_controller.set_cursor_pos(m.doc_id, cursor.Pos.new(final_x, start_pos.y))
			}
		}
	}
}

fn (mut m EditorModel) paste_before() {
	content := m.cb.get_content() or { return }
	if content.data.len == 0 { return }

	match content.@type {
		.block {
			// Block paste: insert as new lines above current line
			cursor_pos := m.doc_controller.cursor_pos(m.doc_id)
			if cursor_pos.y == 0 {
				// At first line: insert newline then move content up
				m.doc_controller.prepare_for_insertion(m.doc_id) or { return }
				// Move to start of first line, insert content then a newline
				for line in content.data.split('\n') {
					for cr in line.runes() {
						m.doc_controller.insert_char(m.doc_id, cr)
					}
					m.doc_controller.insert_newline(m.doc_id)
				}
				// Move cursor back to start of first pasted line
				m.doc_controller.move_cursor_up_by(m.doc_id, content.data.split('\n').len, .normal)
			} else {
				// Move to end of previous line and insert new lines
				m.doc_controller.move_cursor_up(m.doc_id, .normal)
				m.doc_controller.move_cursor_to_line_end(m.doc_id, .insert)
				m.doc_controller.prepare_for_insertion(m.doc_id) or { return }
				for line in content.data.split('\n') {
					m.doc_controller.insert_newline(m.doc_id)
					for cr in line.runes() {
						m.doc_controller.insert_char(m.doc_id, cr)
					}
				}
				// Move cursor to start of first pasted line
				m.doc_controller.move_cursor_up_by(m.doc_id, content.data.split('\n').len - 1, .normal)
			}
		}
		.inline {
			// Inline paste: insert text before cursor
			start_pos := m.doc_controller.cursor_pos(m.doc_id)
			m.doc_controller.prepare_for_insertion(m.doc_id) or { return }
			mut newline_count := 0
			mut last_line_char_count := 0
			for cr in content.data.runes() {
				if cr == `\n` {
					m.doc_controller.insert_newline(m.doc_id)
					newline_count += 1
					last_line_char_count = 0
				} else {
					m.doc_controller.insert_char(m.doc_id, cr)
					last_line_char_count += 1
				}
			}
			// Reposition cursor on last character of pasted text
			if newline_count > 0 {
				final_x := if last_line_char_count > 0 { last_line_char_count - 1 } else { 0 }
				final_y := start_pos.y + newline_count
				m.doc_controller.set_cursor_pos(m.doc_id, cursor.Pos.new(final_x, final_y))
			} else if last_line_char_count > 0 {
				final_x := start_pos.x + last_line_char_count - 1
				m.doc_controller.set_cursor_pos(m.doc_id, cursor.Pos.new(final_x, start_pos.y))
			}
		}
		.none {
			start_pos := m.doc_controller.cursor_pos(m.doc_id)
			m.doc_controller.prepare_for_insertion(m.doc_id) or { return }
			mut newline_count := 0
			mut last_line_char_count := 0
			for cr in content.data.runes() {
				if cr == `\n` {
					m.doc_controller.insert_newline(m.doc_id)
					newline_count += 1
					last_line_char_count = 0
				} else {
					m.doc_controller.insert_char(m.doc_id, cr)
					last_line_char_count += 1
				}
			}
			if newline_count > 0 {
				final_x := if last_line_char_count > 0 { last_line_char_count - 1 } else { 0 }
				final_y := start_pos.y + newline_count
				m.doc_controller.set_cursor_pos(m.doc_id, cursor.Pos.new(final_x, final_y))
			} else if last_line_char_count > 0 {
				final_x := start_pos.x + last_line_char_count - 1
				m.doc_controller.set_cursor_pos(m.doc_id, cursor.Pos.new(final_x, start_pos.y))
			}
		}
	}
}

fn (m EditorModel) debug_data() DebugData {
	cursor_pos := m.doc_controller.cursor_pos(m.doc_id)
	return DebugData{
		name: 'active editor data'
		data: {
			'id':         '${m.id}'
			'file path':  m.file_path
			'cursor_row': '${cursor_pos.y}'
			'cursor_col': '${cursor_pos.x}'
		}
	}
}

fn (m EditorModel) data() EditorData {
	cursor_pos := m.doc_controller.cursor_pos(m.doc_id)
	return EditorData{
		id:        m.id
		file_path: m.file_path

		cursor_row: cursor_pos.y
		cursor_col: cursor_pos.x

		chord_display: m.chord.display()
	}
}

fn (m EditorModel) width() int {
	return m.width
}

fn (m EditorModel) height() int {
	return m.height
}

fn (m EditorModel) clone() tea.Model {
	assert m.file_path.len != 0
	mut c := EditorModel{
		...m
	}
	// each clone gets its own arena, lazily initialized on first view()
	c.arena = Arena{}
	c.rune_buf = []rune{}
	return c
}
