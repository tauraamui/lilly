module main

import tauraamui.bobatea as tea
import theme
import petal
import palette
import documents
import lib.syntax

pub const tab_width = 4

struct EditorData {
	id         int
	file_path  string
	cursor_row int
	cursor_col int
}

struct EditorModel {
	id     int
	doc_id int

	theme     theme.Theme
	file_path string
mut:
	focused     bool
	show_border bool = true

	width  int
	height int
	min_y  int

	doc_controller &documents.Controller
	token_parser   syntax.Parser
	lang_syn       syntax.Syntax
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
}

fn EditorModel.new(opts EditorModelNewParams) EditorModel {
	assert opts.file_path != ''
	return EditorModel{
		id:             opts.id
		file_path:      opts.file_path
		doc_id:         opts.doc_id
		theme:          opts.theme
		doc_controller: opts.doc_controller
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
							'ctrl+i' { m.doc_controller.insert_char(m.doc_id, `\t`) }
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
			.normal {
				match msg.key_msg.k_type {
					.runes {
						cmds << editor_data(m.data())
						match msg.key_msg.string() {
							'o' {
								m.doc_controller.move_cursor_to_line_end(m.doc_id, .insert)
								m.doc_controller.prepare_for_insertion(m.doc_id) or {
									cmds << raise_error('error: ${err}')
									m.ensure_cursor_visible()
									return m.clone(), tea.batch_array(cmds)
								}
								leading_whitespace := m.doc_controller.leading_whitespace_on_current_line(m.doc_id)
								m.doc_controller.insert_newline(m.doc_id)
								for cr in leading_whitespace {
									m.doc_controller.insert_char(m.doc_id, cr)
								}
								cmds << switch_mode(.insert)
								m.ensure_cursor_visible()
								return m.clone(), tea.batch_array(cmds)
							}
							'w' {
								m.doc_controller.move_cursor_to_next_word_start(m.doc_id)
							}
							'b' {
								m.doc_controller.move_cursor_to_previous_word_start(m.doc_id)
							}
							'$' {
								m.doc_controller.move_cursor_to_line_end(m.doc_id, .normal)
							}
							'}' {
								m.doc_controller.move_cursor_to_next_blank_line(m.doc_id)
							}
							'{' {
								m.doc_controller.move_cursor_to_previous_blank_line(m.doc_id)
							}
							'h' {
								m.doc_controller.move_cursor_left(m.doc_id, .normal)
							}
							'j' {
								m.doc_controller.move_cursor_down(m.doc_id, .normal)
							}
							'k' {
								m.doc_controller.move_cursor_up(m.doc_id, .normal)
							}
							'l' {
								m.doc_controller.move_cursor_right(m.doc_id, .normal)
							}
							else {}
						}
					}
					.special {
						match msg.key_msg.string() {
							'delete' {
								m.doc_controller.prepare_for_insertion(m.doc_id) or {
									cmds << raise_error('error: ${err}')
									m.ensure_cursor_visible()
									return m.clone(), tea.batch_array(cmds)
								}
								m.doc_controller.delete(m.doc_id)
								cmds << switch_mode(.insert)
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
					current_line := m.doc_controller.get_line_at(m.doc_id, m.doc_controller.cursor_pos(m.doc_id).y) or { '' }
					if current_line.len > 0 && current_line.trim_space().len == 0 {
						m.doc_controller.clear_line(m.doc_id)
					} else {
						m.doc_controller.move_cursor_left(m.doc_id, .normal)
					}
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

	m.token_parser.reset()
	for y, l in m.doc_controller.get_iterator(m.doc_id) {
		offset_id := ctx.push_offset(tea.Offset{ x: 0 })
		defer { ctx.clear_offsets_from(offset_id) }
		line_content := l.string().expand_tabs(tab_width)
		line_tokens := m.token_parser.parse_line(y, line_content)
		if y >= m.min_y && y < m.min_y + m.height {
			for i, t in line_tokens {
				token_content := line_content.runes()[t.start()..t.end()]
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
							token_content.string() in m.lang_syn.keywords {
								ctx.set_color(m.theme.petal_red)
							}
							token_content.string() in m.lang_syn.literals {
								ctx.set_color(m.theme.syntax_literal)
							}
							token_content.string() in m.lang_syn.builtins {
								ctx.set_color(m.theme.syntax_builtin)
							}
							else {}
						}
						prev_token := if i - 1 >= 0 { ?syntax.Token(line_tokens[i - 1]) } else { ?syntax.Token(none) }
						next_token := if i + 1 < line_tokens.len { ?syntax.Token(line_tokens[i + 1]) } else { ?syntax.Token(none) }

						if pt := prev_token {
							if pt.t_type() != .whitespace && line_content.runes()[pt.start()..pt.end()].string() == '_' { ctx.reset_color() }
						} else {
							if nt := next_token {
								if nt.t_type() != .whitespace && line_content.runes()[nt.start()..nt.end()].string() == '_' { ctx.reset_color() }
							}
						}

					}
				}
				ctx.draw_text(0, y - m.min_y, token_content.string())
				ctx.push_offset(tea.Offset{ x: utf8_str_visible_length(token_content.string()) })
				ctx.reset_color()
			}
		}
	}

	if m.focused {
		m.render_cursor(mut ctx)
	}
}

fn (m EditorModel) render_cursor(mut ctx tea.Context) {
	cursor_pos := m.doc_controller.visual_cursor_pos(m.doc_id, tab_width)
	// basically we want the block cursor to be the inverse of the background shade
	// and then the text/fg color to be the inverse of that/the same as background
	default_bg_color := ctx.get_default_bg_color() or { palette.matte_black_bg_color }
	ctx.set_bg_color(palette.fg_color(default_bg_color))
	ctx.set_color(default_bg_color)
	ctx.draw_text(cursor_pos.x, cursor_pos.y - m.min_y, m.doc_controller.get_char_at(m.doc_id) or { ' ' }.expand_tabs(tab_width))
	ctx.reset_bg_color()
	ctx.reset_color()
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
	return EditorModel{
		...m
	}
}
