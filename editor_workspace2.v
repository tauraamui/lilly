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
			m.resized_update(msg)
		}
		OpenEditorInWorkspaceMsg {
			return m.open_editor_in_workspace_update(msg)
		}
		else {}
	}

	if mut active_editor := m.active_editor {
		new_active_editor, cmd := active_editor.update(msg)
		if new_active_editor is DebuggableModel {
			m.active_editor = new_active_editor
		}
		return m.clone(), cmd
	}

	return m.clone(), tea.noop_cmd
}

fn (mut m EditorWorkspaceModel2) key_update(msg tea.KeyMsg) (tea.Model, fn () tea.Msg) {
	if msg.k_type == .special && msg.string() == 'escape' {
		return m.clone(), tea.quit
	}

	if mut active_editor := m.active_editor {
		new_active_editor, cmd := active_editor.update(EditorModelKeyMsg{
			key_msg: msg
			mode: m.mode
		})
		if new_active_editor is DebuggableModel {
			m.active_editor = new_active_editor
		}
		return m.clone(), tea.batch(cmd, debug_log('mode on key press: ${m.mode}'))
	}
	return m.clone(), tea.noop_cmd
}

fn (mut m EditorWorkspaceModel2) resized_update(msg tea.ResizedMsg) {
	m.width = msg.window_width
	m.height = msg.window_height
}

fn (mut m EditorWorkspaceModel2) open_editor_in_workspace_update(msg OpenEditorInWorkspaceMsg) (tea.Model, fn () tea.Msg) {
	doc_id := m.doc_controller.open_document(msg.file_path) or {
		return m.clone(), debug_log('failed to open document ${msg.file_path}: ${err}')
	}
	mut e_model := EditorModel2.new(m.theme, 0, doc_id, msg.file_path, m.doc_controller)
	model_init_cmd := e_model.init()
	m.active_editor = e_model
	return m.clone(), tea.sequence(model_init_cmd)
}

fn (m EditorWorkspaceModel2) view(mut ctx tea.Context) {
	if mut editor := m.active_editor {
		editor.view(mut ctx)
		return
	}
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


