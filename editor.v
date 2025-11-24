module main

import tauraamui.bobatea as tea

struct EditorModel {
	file_path string // NOTE(tauraamui): this will eventually be a buffer reference
}

struct OpenEditorMsg {
	file_path string
}

fn open_editor(file_path string) tea.Cmd {
	return fn [file_path] () tea.Msg {
		return OpenEditorMsg{ file_path }
	}
}

fn EditorModel.new(file_path string) EditorModel {
	assert file_path.len != 0
	return EditorModel{ file_path }
}

fn (mut m EditorModel) init() ?tea.Cmd {
	return none
}

fn (mut m EditorModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	return m.clone(), none
}

fn (m EditorModel) view(mut ctx tea.Context) {
	ctx.set_bg_color(tea.Color{ 20, 20, 20 })
	defer { ctx.reset_color() }
	ctx.draw_rect(0, 0, ctx.window_width(), ctx.window_height())
	ctx.draw_text(0, 0, "editing ${m.file_path}")
}

fn (m EditorModel) debug_data() DebugData {
	return DebugData{
		name: 'active editor data'
		data: {
			'file path': m.file_path
		}
	}
}

fn (m EditorModel) clone() tea.Model {
	assert m.file_path.len != 0
	return EditorModel{
		...m
	}
}

