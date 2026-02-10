module main

import tauraamui.bobatea as tea
import documents

fn test_cursor_up_moves_up() {
	mut cursor := ModelCursorPos{}
	assert cursor.x == 0
	assert cursor.y == 0

	cursor = cursor.left()
	assert cursor.x == 0
	assert cursor.y == 0

	cursor = cursor.down(max_height: 100)
	assert cursor.x == 0
	assert cursor.y == 1

	cursor = cursor.up()
	assert cursor.x == 0
	assert cursor.y == 0

	cursor = cursor.right(max_width: 100)
	assert cursor.x == 1
	assert cursor.y == 0

	cursor = cursor.down(max_height: 100)
	assert cursor.x == 0
	assert cursor.y == 1

	cursor = cursor.right(distance: 99, max_width: 100)
	assert cursor.x == 99
	assert cursor.y == 1
}

fn test_editor_handles_key_hjkl() {
	mut doc_controller := documents.Controller.new()
	defer { doc_controller.free() }

	doc_id := doc_controller.open_document('./editor_test.v')!
	editor_id := 0
	mut editor := EditorModel.new(editor_id, './editor_test.v', doc_id, &doc_controller)

	// sending focus msg with the matching id will make it handle subsequent input
	mut e_model, mut cmd := editor.update(EditorModelMsg{
		id: editor_id
		msg: tea.FocusedMsg{}
		mode: .normal
	})

	assert e_model is EditorModel
	if mut e_model is EditorModel {
		editor = e_model
	}

	e_model, cmd = editor.update(EditorModelKeyMsg{
		key_msg: tea.KeyMsg{
			runes: [`l`]
		}
		mode: .normal
	})

	assert e_model is EditorModel
	if mut e_model is EditorModel {
		editor = e_model
	}
}

