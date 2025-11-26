module main

import tauraamui.bobatea as tea

struct EditorData {
	file_path  string
	cursor_row int
	cursor_col int
}

struct EditorModel {
	file_path string
mut:
	cursor_row int
	cursor_col int
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

fn query_editor_data() tea.Msg {
	return QueryEditorDataMsg{}
}

struct EditorDataResultMsg {
	data EditorData
}

fn editor_data(data EditorData) tea.Cmd {
	return fn [data] () tea.Msg {
		return EditorDataResultMsg{ data }
	}
}

fn EditorModel.new(file_path string) EditorModel {
	assert file_path.len != 0
	return EditorModel{ file_path: file_path }
}

fn (mut m EditorModel) init() ?tea.Cmd {
	return none
}

fn (mut m EditorModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	match msg {
		QueryEditorDataMsg {
			return m.clone(), editor_data(m.data())
		}
		else {}
	}
	return m.clone(), none
}

fn (m EditorModel) view(mut ctx tea.Context) {}

fn (m EditorModel) debug_data() DebugData {
	return DebugData{
		name: 'active editor data'
		data: {
			'file path': m.file_path
		}
	}
}

fn (m EditorModel) data() EditorData {
	return EditorData{
		file_path:  m.file_path
		cursor_row: m.cursor_row
		cursor_col: m.cursor_col
	}
}

fn (m EditorModel) clone() tea.Model {
	assert m.file_path.len != 0
	return EditorModel{
		...m
	}
}

