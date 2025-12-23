module main

import os
import tauraamui.bobatea as tea

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
	focused    bool
	cursor_row int
	cursor_col int

	width  int
	height int

	lines []string
}

struct OpenEditorMsg {
	file_path string
}

fn open_editor(file_path string) tea.Cmd {
	return fn [file_path] () tea.Msg {
		return OpenEditorMsg{ file_path }
	}
}

struct QueryEditorDataMsg {}

fn query_editor_data(id int) tea.Cmd {
	return fn [id] () tea.Msg {
		return EditorModelMsg {
			id: id
			msg: QueryEditorDataMsg{}
		}
	}
}

struct EditorDataResultMsg {
	data EditorData
}

fn editor_data(data EditorData) tea.Cmd {
	return fn [data] () tea.Msg {
		return EditorDataResultMsg{ data }
	}
}

fn EditorModel.new(id int, file_path string) EditorModel {
	assert file_path.len != 0
	return EditorModel{
		id: id,
		file_path: file_path,
		lines: if content := os.read_lines(file_path) { content } else { []string{ len: 150, init: "This is a line of random text" } }
	}
}

fn (mut m EditorModel) init() ?tea.Cmd {
	return tea.emit_resize
}

struct EditorModelMsg {
	id  int
	msg tea.Msg
}

fn (mut m EditorModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	match msg {
		tea.ResizedMsg {
			m.width  = msg.window_width
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
						return m.clone(), editor_data(m.data())
					}
				}
				else {}
			}
		}
		else {}
	}
	return m.clone(), none
}

fn (m EditorModel) view(mut ctx tea.Context) {
	ctx.set_clip_area(tea.ClipArea{ 0, 0, m.width, m.height })
	defer { ctx.clear_clip_area() }

	bg_color := if m.focused { tea.Color{ 20, 120, 20 } } else { tea.Color{ 120, 20, 20 } }
	ctx.set_bg_color(bg_color)
	ctx.draw_rect(0, 0, m.width, m.height)
	ctx.reset_bg_color()

	for y, l in m.lines {
		ctx.draw_text(0, y, l.replace('\t', '    '))
	}
}

fn (m EditorModel) debug_data() DebugData {
	return DebugData{
		name: 'active editor data'
		data: {
			'id': '${m.id}'
			'file path': m.file_path
			'cursor_row': '${m.cursor_row}'
			'cursor_col': '${m.cursor_col}'
		}
	}
}

fn (m EditorModel) data() EditorData {
	return EditorData{
		id:         m.id
		file_path:  m.file_path
		cursor_row: m.cursor_row
		cursor_col: m.cursor_col
	}
}

fn (m EditorModel) width() int { return m.width }

fn (m EditorModel) height() int { return m.height }

fn (m EditorModel) clone() tea.Model {
	assert m.file_path.len != 0
	return EditorModel{
		...m
	}
}

