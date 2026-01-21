module main

import os
import tauraamui.bobatea as tea
import palette

struct ModelCursorPos {
	x int
	y int
}

fn (c ModelCursorPos) up() ModelCursorPos {
	yy := c.y - 1
	if yy < 0 {
		return c
	}
	return ModelCursorPos{
		y: yy
		x: 0
	}
}

fn (c ModelCursorPos) down(max int) ModelCursorPos {
	yy := c.y + 1
	if yy >= max {
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

fn (c ModelCursorPos) right(max int) ModelCursorPos {
	yy := c.y + 1
	if yy >= max {
		return c
	}
	return ModelCursorPos{
		y: yy
		x: 0
	}
}

struct EditorData {
	id         int
	file_path  string
	cursor_row int
	cursor_col int
}

struct EditorModel {
	id        int
	file_path string
mut:
	focused     bool
	show_border bool = true
	cursor_pos  ModelCursorPos

	width  int
	height int

	lines []string
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

fn EditorModel.new(id int, file_path string) EditorModel {
	assert file_path.len != 0
	return EditorModel{
		id:        id
		file_path: file_path
		lines:     if content := os.read_lines(file_path) {
			content
		} else {
			[]string{len: 150, init: 'This is a line of random text'}
		}
	}
}

fn (mut m EditorModel) init() ?tea.Cmd {
	return tea.emit_resize
}

struct EditorModelMsg {
	id  int
	msg tea.Msg
}

// this is physically painful to implement, but it'll do for now
struct EditorCursorDownMsg {
	editor_id int
}

fn move_cursor_down() tea.Msg {
	return EditorCursorDownMsg{}
}

// ugh - vom
struct EditorCursorUpMsg {
	editor_id int
}

fn move_cursor_up() tea.Msg {
	return EditorCursorUpMsg{}
}

fn (mut m EditorModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	mut cmds := []tea.Cmd{}

	if msg is tea.KeyMsg && m.focused {
		match msg.k_type {
			.runes {
				match msg.string() {
					'j' {
						cmds << move_cursor_down
						return m.clone(), tea.batch_array(cmds)
					}
					'k' {
						cmds << move_cursor_up
						return m.clone(), tea.batch_array(cmds)
					}
					else {}
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
		EditorCursorUpMsg {
			if m.focused {
				m.cursor_pos = m.cursor_pos.up()
			}
		}
		EditorCursorDownMsg {
			if m.focused {
				m.cursor_pos = m.cursor_pos.down(m.height)
			}
		}
		else {}
	}
	return m.clone(), tea.batch_array(cmds)
}

const active_editor_border_color = palette.petal_pink_color
const inactive_editor_border_color = palette.status_dark_lilac

fn (m EditorModel) view(mut ctx tea.Context) {
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

	for y, l in m.lines {
		ctx.draw_text(0, y, l.replace('\t', '    '))
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
