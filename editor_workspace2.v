module main

import bobatea as tea
import lib.petal
import lib.petal.theme
import lib.boba
import lib.documents

struct EditorWorkspaceModel2 {
	mode           petal.Mode = .normal
	theme          theme.Theme
	doc_controller &documents.Controller2
mut:
	width          int
	height         int
	dialog_model   ?DebuggableModel
	input_field    boba.InputField

	active_editor  ?DebuggableModel // underlying type of Editor2
}

fn EditorWorkspaceModel2.new(l_theme theme.Theme, doc_controller &documents.Controller2) EditorWorkspaceModel2 {
	return EditorWorkspaceModel2{
		theme: l_theme
		doc_controller: doc_controller
	}
}

fn (mut m EditorWorkspaceModel2) init() fn () tea.Msg {
	m.input_field = boba.InputField.new_with_prefix(':', 0)
	return tea.emit_resize
}

fn (mut m EditorWorkspaceModel2) update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
	match msg {
		tea.KeyMsg {
			return m.key_update(msg)
		}
		tea.ResizedMsg {
			return m.resized_update(msg)
		}
		OpenEditorInWorkspaceMsg {
			return m.open_editor_in_workspace_update(msg)
		}
		else {}
	}
	return m.clone(), tea.noop_cmd
}

fn (mut m EditorWorkspaceModel2) key_update(msg tea.KeyMsg) (tea.Model, fn () tea.Msg) {
	if msg.k_type == .special && msg.string() == 'escape' {
		return m.clone(), tea.quit
	}
	return m.clone(), tea.noop_cmd
}

fn (mut m EditorWorkspaceModel2) resized_update(msg tea.ResizedMsg) (tea.Model, fn () tea.Msg) {
	m.width = msg.window_width
	m.height = msg.window_height
	return m.clone(), tea.noop_cmd
}

fn (mut m EditorWorkspaceModel2) open_editor_in_workspace_update(msg OpenEditorInWorkspaceMsg) (tea.Model, fn () tea.Msg) {
	return m.clone(), tea.noop_cmd
}

fn (m EditorWorkspaceModel2) view(mut ctx tea.Context) {
	ctx.draw_text(0, 0, 'Editor Workspace WIP')
}

fn (m EditorWorkspaceModel2) width() int {
	return m.width
}

fn (m EditorWorkspaceModel2) height() int {
	return m.height
}

fn (m EditorWorkspaceModel2) debug_data() DebugData {
	return DebugData{
		name: 'editor workspace'
	}
}

fn (m EditorWorkspaceModel2) clone() tea.Model {
	return EditorWorkspaceModel2{
		...m
	}
}

fn (m EditorWorkspaceModel2) clone_with_mode(mode petal.Mode) tea.Model {
	return EditorWorkspaceModel2{
		...m
		mode: mode
	}
}

struct OpenEditorInWorkspaceMsg {
	file_path string
}

fn open_editor_in_workspace_cmd(file_path string) fn () tea.Msg {
	return fn [file_path] () tea.Msg {
		return OpenEditorInWorkspaceMsg{
			file_path: file_path
		}
	}
}


