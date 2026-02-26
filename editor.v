module main

import tauraamui.bobatea as tea
import petal
import palette
import documents

struct EditorData {
	id         int
	file_path  string
	cursor_row int
	cursor_col int
}

struct EditorModel {
	id     int
	doc_id int

	file_path string
mut:
	focused     bool
	show_border bool = true

	width  int
	height int

	doc_controller &documents.Controller
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

fn EditorModel.new(id int, file_path string, doc_id int, doc_controller &documents.Controller) EditorModel {
	assert file_path != ''
	return EditorModel{
		id:             id
		file_path:      file_path
		doc_id:         doc_id
		doc_controller: doc_controller
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
						char_runes := msg.key_msg.string().runes()
						for cr in char_runes {
							m.doc_controller.insert_char(m.doc_id, cr)
						}
					}
					.special {
						match msg.key_msg.string() {
							'enter' { m.doc_controller.insert_newline(m.doc_id) }
							'left' {
								m.doc_controller.move_cursor_left(m.doc_id, .insert)
								m.doc_controller.prepare_for_insertion(m.doc_id) or {
									cmds << raise_error('error: ${err}')
									return m.clone(), tea.batch_array(cmds)
								}
							}
							'up' {
								m.doc_controller.move_cursor_down(m.doc_id, .insert)
								m.doc_controller.prepare_for_insertion(m.doc_id) or {
									cmds << raise_error('error: ${err}')
									return m.clone(), tea.batch_array(cmds)
								}
							}
							'right' {
								m.doc_controller.move_cursor_right(m.doc_id, .insert)
								m.doc_controller.prepare_for_insertion(m.doc_id) or {
									cmds << raise_error('error: ${err}')
									return m.clone(), tea.batch_array(cmds)
								}
							}
							'down' {
								m.doc_controller.move_cursor_up(m.doc_id, .insert)
								m.doc_controller.prepare_for_insertion(m.doc_id) or {
									cmds << raise_error('error: ${err}')
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
									return m.clone(), tea.batch_array(cmds)
								}
								m.doc_controller.insert_newline(m.doc_id)
								cmds << switch_mode(.insert)
								return m.clone(), tea.batch_array(cmds)
							}
							'h' {
								m.doc_controller.move_cursor_left(m.doc_id, .normal)
							}
							'j' {
								m.doc_controller.move_cursor_up(m.doc_id, .normal)
							}
							'k' {
								m.doc_controller.move_cursor_down(m.doc_id, .normal)
							}
							'l' {
								m.doc_controller.move_cursor_right(m.doc_id, .normal)
							}
							else {}
						}
					}
					.special {
						match msg.key_msg.string() {
							'left' {
								m.doc_controller.move_cursor_left(m.doc_id, .normal)
							}
							'up' {
								m.doc_controller.move_cursor_down(m.doc_id, .normal)
							}
							'right' {
								m.doc_controller.move_cursor_right(m.doc_id, .normal)
							}
							'down' {
								m.doc_controller.move_cursor_up(m.doc_id, .normal)
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
			if msg.mode == .insert && m.focused {
				m.doc_controller.prepare_for_insertion(m.doc_id) or {
					cmds << raise_error('switch mode error: ${err}')
					return m.clone(), tea.batch_array(cmds)
				}
				/*
				m.doc_controller.prepare_for_insertion_at(m.doc_id, documents.CursorPos{
					x: c_x
					y: c_y
				}) or {
					cmds << raise_error('switch mode error: ${err}')
					return m.clone(), tea.batch_array(cmds)
				}
				*/
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

	for y, l in m.doc_controller.get_iterator(m.doc_id) {
		ctx.draw_text(0, y, l.string().replace('\t', '    '))
	}

	if m.focused {
		m.render_cursor(mut ctx)
	}
}

fn (m EditorModel) render_cursor(mut ctx tea.Context) {
	cursor_pos := m.doc_controller.cursor_pos(m.doc_id)
	default_bg_color := ctx.get_default_bg_color() or { palette.matte_black_bg_color }
	ctx.set_bg_color(palette.fg_color(default_bg_color))
	ctx.draw_rect(cursor_pos.x, cursor_pos.y, 1, 1)
	ctx.reset_bg_color()
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
