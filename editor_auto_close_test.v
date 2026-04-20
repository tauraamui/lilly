module main

import os
import time
import lib.documents
import lib.documents.cursor
import lib.clipboard
import lib.petal.theme
import lib.syntax

fn make_temp_file_with_contents(label string, contents string) string {
	path := os.join_path(os.temp_dir(), 'lilly_${label}_${time.now().unix_nano()}')
	os.write_file(path, contents) or { panic('failed to write temp file: ${err}') }
	return path
}

fn test_editor_model_insert_rune_auto_closes_parentheses() {
	file_path := make_temp_file_with_contents('auto_paren', '')
	defer { os.rm(file_path) or {} }

	mut ctrl := documents.Controller{}
	doc_id := ctrl.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut cb := clipboard.new()
	mut editor := EditorModel.new(
		id:             101
		theme:          theme.dark_theme
		file_path:      file_path
		doc_id:         doc_id
		doc_controller: &ctrl
		cb:             &cb
		expand_tabs:    false
		tab_width:      4
	)
	editor.lang_syn = syntax.Syntax{
		name: 'test'
	}

	editor.doc_controller.prepare_for_insertion_at(editor.doc_id, editor.cursor_pos) or {
		panic('prepare_for_insertion_at failed: ${err}')
	}

	editor.insert_rune(`(`)

	first_line := editor.doc_controller.get_line_at(editor.doc_id, 0) or { '' }
	assert first_line == '()'
	assert editor.cursor_pos == cursor.Pos.new(1, 0)

	editor.insert_rune(`a`)

	updated_line := editor.doc_controller.get_line_at(editor.doc_id, 0) or { '' }
	assert updated_line == '(a)'
	assert editor.cursor_pos == cursor.Pos.new(2, 0)
}

fn test_editor_model_insert_rune_auto_closes_braces() {
	file_path := make_temp_file_with_contents('auto_brace', '')
	defer { os.rm(file_path) or {} }

	mut ctrl := documents.Controller{}
	doc_id := ctrl.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut cb := clipboard.new()
	mut editor := EditorModel.new(
		id:             102
		theme:          theme.dark_theme
		file_path:      file_path
		doc_id:         doc_id
		doc_controller: &ctrl
		cb:             &cb
		expand_tabs:    false
		tab_width:      4
	)
	editor.lang_syn = syntax.Syntax{
		name: 'test'
	}

	editor.doc_controller.prepare_for_insertion_at(editor.doc_id, editor.cursor_pos) or {
		panic('prepare_for_insertion_at failed: ${err}')
	}

	editor.insert_rune(`{`)

	first_line := editor.doc_controller.get_line_at(editor.doc_id, 0) or { '' }
	assert first_line == '{}'
	assert editor.cursor_pos == cursor.Pos.new(1, 0)

	editor.insert_rune(`b`)

	updated_line := editor.doc_controller.get_line_at(editor.doc_id, 0) or { '' }
	assert updated_line == '{b}'
	assert editor.cursor_pos == cursor.Pos.new(2, 0)
}

fn test_editor_model_insert_rune_auto_closes_double_quotes() {
	file_path := make_temp_file_with_contents('auto_double', '')
	defer { os.rm(file_path) or {} }

	mut ctrl := documents.Controller{}
	doc_id := ctrl.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut cb := clipboard.new()
	mut editor := EditorModel.new(
		id:             104
		theme:          theme.dark_theme
		file_path:      file_path
		doc_id:         doc_id
		doc_controller: &ctrl
		cb:             &cb
		expand_tabs:    false
		tab_width:      4
	)
	editor.lang_syn = syntax.Syntax{
		name: 'test'
	}

	editor.doc_controller.prepare_for_insertion_at(editor.doc_id, editor.cursor_pos) or {
		panic('prepare_for_insertion_at failed: ${err}')
	}

	editor.insert_rune(`"`)

	first_line := editor.doc_controller.get_line_at(editor.doc_id, 0) or { '' }
	assert first_line == '""'
	assert editor.cursor_pos == cursor.Pos.new(1, 0)

	editor.insert_rune(`x`)

	updated_line := editor.doc_controller.get_line_at(editor.doc_id, 0) or { '' }
	assert updated_line == '"x"'
	assert editor.cursor_pos == cursor.Pos.new(2, 0)
}

fn test_editor_model_insert_rune_auto_closes_single_quotes() {
	file_path := make_temp_file_with_contents('auto_single', '')
	defer { os.rm(file_path) or {} }

	mut ctrl := documents.Controller{}
	doc_id := ctrl.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut cb := clipboard.new()
	mut editor := EditorModel.new(
		id:             105
		theme:          theme.dark_theme
		file_path:      file_path
		doc_id:         doc_id
		doc_controller: &ctrl
		cb:             &cb
		expand_tabs:    false
		tab_width:      4
	)
	editor.lang_syn = syntax.Syntax{
		name: 'test'
	}

	editor.doc_controller.prepare_for_insertion_at(editor.doc_id, editor.cursor_pos) or {
		panic('prepare_for_insertion_at failed: ${err}')
	}

	editor.insert_rune(`'`)

	first_line := editor.doc_controller.get_line_at(editor.doc_id, 0) or { '' }
	assert first_line == "''"
	assert editor.cursor_pos == cursor.Pos.new(1, 0)

	editor.insert_rune(`c`)

	updated_line := editor.doc_controller.get_line_at(editor.doc_id, 0) or { '' }
	assert updated_line == "'c'"
	assert editor.cursor_pos == cursor.Pos.new(2, 0)
}

fn test_editor_model_insert_rune_auto_closes_backticks() {
	file_path := make_temp_file_with_contents('auto_backtick', '')
	defer { os.rm(file_path) or {} }

	mut ctrl := documents.Controller{}
	doc_id := ctrl.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut cb := clipboard.new()
	mut editor := EditorModel.new(
		id:             106
		theme:          theme.dark_theme
		file_path:      file_path
		doc_id:         doc_id
		doc_controller: &ctrl
		cb:             &cb
		expand_tabs:    false
		tab_width:      4
	)
	editor.lang_syn = syntax.Syntax{
		name: 'test'
	}

	editor.doc_controller.prepare_for_insertion_at(editor.doc_id, editor.cursor_pos) or {
		panic('prepare_for_insertion_at failed: ${err}')
	}

	editor.insert_rune(rune(96))

	first_line := editor.doc_controller.get_line_at(editor.doc_id, 0) or { '' }
	assert first_line == '``'
	assert editor.cursor_pos == cursor.Pos.new(1, 0)

	editor.insert_rune(`d`)

	updated_line := editor.doc_controller.get_line_at(editor.doc_id, 0) or { '' }
	assert updated_line == '`d`'
	assert editor.cursor_pos == cursor.Pos.new(2, 0)
}

fn test_editor_model_insert_rune_without_syntax_does_not_auto_close_parentheses() {
	file_path := make_temp_file_with_contents('auto_none', '')
	defer { os.rm(file_path) or {} }

	mut ctrl := documents.Controller{}
	doc_id := ctrl.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut cb := clipboard.new()
	mut editor := EditorModel.new(
		id:             103
		theme:          theme.dark_theme
		file_path:      file_path
		doc_id:         doc_id
		doc_controller: &ctrl
		cb:             &cb
		expand_tabs:    false
		tab_width:      4
	)

	editor.doc_controller.prepare_for_insertion_at(editor.doc_id, editor.cursor_pos) or {
		panic('prepare_for_insertion_at failed: ${err}')
	}

	editor.insert_rune(`(`)

	first_line := editor.doc_controller.get_line_at(editor.doc_id, 0) or { '' }
	assert first_line == '('
	assert editor.cursor_pos == cursor.Pos.new(1, 0)
}

fn test_editor_model_insert_rune_without_syntax_does_not_auto_close_double_quotes() {
	file_path := make_temp_file_with_contents('auto_none_double', '')
	defer { os.rm(file_path) or {} }

	mut ctrl := documents.Controller{}
	doc_id := ctrl.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut cb := clipboard.new()
	mut editor := EditorModel.new(
		id:             107
		theme:          theme.dark_theme
		file_path:      file_path
		doc_id:         doc_id
		doc_controller: &ctrl
		cb:             &cb
		expand_tabs:    false
		tab_width:      4
	)

	editor.doc_controller.prepare_for_insertion_at(editor.doc_id, editor.cursor_pos) or {
		panic('prepare_for_insertion_at failed: ${err}')
	}

	editor.insert_rune(`"`)

	first_line := editor.doc_controller.get_line_at(editor.doc_id, 0) or { '' }
	assert first_line == '"'
	assert editor.cursor_pos == cursor.Pos.new(1, 0)
}

fn test_editor_model_insert_rune_without_syntax_does_not_auto_close_single_quotes() {
	file_path := make_temp_file_with_contents('auto_none_single', '')
	defer { os.rm(file_path) or {} }

	mut ctrl := documents.Controller{}
	doc_id := ctrl.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut cb := clipboard.new()
	mut editor := EditorModel.new(
		id:             108
		theme:          theme.dark_theme
		file_path:      file_path
		doc_id:         doc_id
		doc_controller: &ctrl
		cb:             &cb
		expand_tabs:    false
		tab_width:      4
	)

	editor.doc_controller.prepare_for_insertion_at(editor.doc_id, editor.cursor_pos) or {
		panic('prepare_for_insertion_at failed: ${err}')
	}

	editor.insert_rune(`'`)

	first_line := editor.doc_controller.get_line_at(editor.doc_id, 0) or { '' }
	assert first_line == "'"
	assert editor.cursor_pos == cursor.Pos.new(1, 0)
}

fn test_editor_model_insert_rune_without_syntax_does_not_auto_close_backticks() {
	file_path := make_temp_file_with_contents('auto_none_backtick', '')
	defer { os.rm(file_path) or {} }

	mut ctrl := documents.Controller{}
	doc_id := ctrl.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut cb := clipboard.new()
	mut editor := EditorModel.new(
		id:             109
		theme:          theme.dark_theme
		file_path:      file_path
		doc_id:         doc_id
		doc_controller: &ctrl
		cb:             &cb
		expand_tabs:    false
		tab_width:      4
	)

	editor.doc_controller.prepare_for_insertion_at(editor.doc_id, editor.cursor_pos) or {
		panic('prepare_for_insertion_at failed: ${err}')
	}

	editor.insert_rune(rune(96))

	first_line := editor.doc_controller.get_line_at(editor.doc_id, 0) or { '' }
	assert first_line == '`'
	assert editor.cursor_pos == cursor.Pos.new(1, 0)
}
