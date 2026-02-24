module main

import tauraamui.bobatea as tea
import palette
import documents

struct ModelCursorPos {
	x int
	y int
}

@[params]
struct ModelCursorPosParams {
	distance   int = 1
	max_width  int
	max_height int
}

fn (c ModelCursorPos) up(opts ModelCursorPosParams) ModelCursorPos {
	yy := c.y - opts.distance
	if yy < 0 {
		return c
	}
	return ModelCursorPos{
		y: yy
		x: 0
	}
}

fn (c ModelCursorPos) down(opts ModelCursorPosParams) ModelCursorPos {
	yy := c.y + opts.distance
	if yy >= opts.max_height {
		return c
	}
	return ModelCursorPos{
		y: yy
		x: 0
	}
}

fn (c ModelCursorPos) left() ModelCursorPos {
	xx := c.x - 1
	if xx < 0 {
		return c
	}
	return ModelCursorPos{
		y: c.y
		x: xx
	}
}

fn (c ModelCursorPos) right(opts ModelCursorPosParams) ModelCursorPos {
	xx := c.x + opts.distance
	if xx >= opts.max_width {
		return c
	}
	return ModelCursorPos{
		y: c.y
		x: xx
	}
}

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
	cursor_pos  ModelCursorPos

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
		id:        id
		file_path: file_path
		doc_id: doc_id
		doc_controller: doc_controller
	}
}

fn (mut m EditorModel) init() ?tea.Cmd {
	return tea.emit_resize
}

struct EditorModelMsg {
	id   int
	msg  tea.Msg
	mode Mode
}

struct EditorModelKeyMsg {
	key_msg  tea.KeyMsg
	mode     Mode
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
							m.cursor_pos = m.cursor_pos.right(max_width: 100)
						}
					}
					.special {
						match msg.key_msg.string() {
							'enter' { m.doc_controller.insert_char(m.doc_id, `\n`) }
							else {}
						}
					}
				}
			}
			.normal {
				if msg.key_msg.k_type == .runes {
					cmds << editor_data(m.data())
					match msg.key_msg.string() {
						'h' {}
						'j' {
							m.cursor_pos = m.cursor_pos.down(max_height: m.height)
							assert m.cursor_pos.y > 0
						}
						'k' {
							m.cursor_pos = m.cursor_pos.up()
						}
						'l' {
							m.cursor_pos = m.cursor_pos.right(max_width: 100)
						}
						else {}
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
				c_x := m.cursor_pos.x
				c_y := m.cursor_pos.y
				m.doc_controller.prepare_for_insertion_at(m.doc_id, documents.CursorPos{ x: c_x, y: c_y}) or {
					cmds << raise_error('switch mode error: ${err}')
					return m.clone(), tea.batch_array(cmds)
				}
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
	default_bg_color := ctx.get_default_bg_color() or { palette.matte_black_bg_color }
	ctx.set_bg_color(palette.fg_color(default_bg_color))
	ctx.draw_rect(m.cursor_pos.x, m.cursor_pos.y, 1, 1)
	ctx.reset_bg_color()
}

fn (m EditorModel) debug_data() DebugData {
	return DebugData{
		name: 'active editor data'
		data: {
			'id':         '${m.id}'
			'file path':  m.file_path
			'cursor_row': '${m.cursor_pos.y}'
			'cursor_col': '${m.cursor_pos.x}'
		}
	}
}

fn (m EditorModel) data() EditorData {
	return EditorData{
		id:         m.id
		file_path:  m.file_path

		cursor_row: m.cursor_pos.y
		cursor_col: m.cursor_pos.x
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
