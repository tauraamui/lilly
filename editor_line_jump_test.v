// Copyright 2026 The Lilly Edtior contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

module main

import os
import time
import bobatea as tea
import lib.documents
import lib.documents.cursor
import lib.clipboard
import lib.petal.theme

fn make_temp_file(label string, line_count int) string {
	mut lines := []string{cap: line_count}
	for i in 0 .. line_count {
		lines << 'line ${i}'
	}
	path := os.join_path(os.temp_dir(), 'lilly_${label}_${time.now().unix_nano()}')
	os.write_file(path, lines.join('\n')) or { panic('failed to write temp file: ${err}') }
	return path
}

fn test_editor_model_goto_line_centers_view() {
	file_path := make_temp_file('center', 40)
	defer { os.rm(file_path) or {} }

	mut ctrl := documents.Controller{}
	doc_id := ctrl.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut cb := clipboard.new()
	mut editor := EditorModel.new(
		id:             1
		theme:          theme.dark_theme
		file_path:      file_path
		doc_id:         doc_id
		doc_controller: &ctrl
		cb:             &cb
		expand_tabs:    false
		tab_width:      4
	)
	editor.height = 7

	editor.goto_line(10)

	assert editor.cursor_pos == cursor.Pos.new(0, 9)
	expected_min := 9 - editor.height / 2
	assert editor.min_y == expected_min
}

fn test_editor_model_goto_line_clamps_to_document_end() {
	file_path := make_temp_file('clamp', 40)
	defer { os.rm(file_path) or {} }

	mut ctrl := documents.Controller{}
	doc_id := ctrl.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut cb := clipboard.new()
	mut editor := EditorModel.new(
		id:             2
		theme:          theme.dark_theme
		file_path:      file_path
		doc_id:         doc_id
		doc_controller: &ctrl
		cb:             &cb
		expand_tabs:    false
		tab_width:      4
	)
	editor.height = 7

	editor.goto_line(1000)

	expected_line := ctrl.line_count(doc_id) - 1
	assert editor.cursor_pos == cursor.Pos.new(0, expected_line)
	mut expected_min := ctrl.line_count(doc_id) - editor.height
	if expected_min < 0 {
		expected_min = 0
	}
	assert editor.min_y == expected_min
}

fn test_editor_model_goto_line_with_large_viewport_sets_min_y_to_zero() {
	file_path := make_temp_file('large_view', 4)
	defer { os.rm(file_path) or {} }

	mut ctrl := documents.Controller{}
	doc_id := ctrl.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut cb := clipboard.new()
	mut editor := EditorModel.new(
		id:             3
		theme:          theme.dark_theme
		file_path:      file_path
		doc_id:         doc_id
		doc_controller: &ctrl
		cb:             &cb
		expand_tabs:    false
		tab_width:      4
	)
	editor.height = 20

	editor.goto_line(3)

	assert editor.min_y == 0
}

fn test_line_jump_command_for_returns_goto_line_command() {
	file_path := make_temp_file('workspace', 10)
	defer { os.rm(file_path) or {} }

	mut ctrl := documents.Controller{}
	doc_id := ctrl.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut cb := clipboard.new()
	mut editor := EditorModel.new(
		id:             4
		theme:          theme.dark_theme
		file_path:      file_path
		doc_id:         doc_id
		doc_controller: &ctrl
		cb:             &cb
		expand_tabs:    false
		tab_width:      4
	)

	mut workspace := EditorWorkspaceModel.new(EditorWorkspaceModelParams{
		version:           'test'
		ttheme:            theme.dark_theme
		leader_key:        ' '
		initial_file_path: file_path
		doc_controller:    &ctrl
		clip_manager:      &cb
		expand_tabs:       false
		tab_width:         4
	})
	workspace.active_editor_id = editor.id
	workspace.editors[editor.id] = editor

	cmd := workspace.line_jump_command_for('12') or { panic('expected goto line command') }
	msg := cmd()
	assert msg is EditorModelMsg
	if msg is EditorModelMsg {
		assert msg.id == editor.id
		assert msg.msg is GoToLineMsg
		if msg.msg is GoToLineMsg {
			assert msg.msg.line == 12
		}
	}
}

fn test_line_jump_command_for_rejects_non_numeric_commands() {
	mut ctrl := documents.Controller{}
	mut cb := clipboard.new()
	mut workspace := EditorWorkspaceModel.new(EditorWorkspaceModelParams{
		version:           'test'
		ttheme:            theme.dark_theme
		leader_key:        ' '
		initial_file_path: ''
		doc_controller:    &ctrl
		clip_manager:      &cb
		expand_tabs:       false
		tab_width:         4
	})
	if _ := workspace.line_jump_command_for('wq') {
		assert false
	} else {
		assert true
	}
}

fn test_editor_model_zz_centers_current_line() {
	file_path := make_temp_file('zz_center', 40)
	defer { os.rm(file_path) or {} }

	mut ctrl := documents.Controller{}
	doc_id := ctrl.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut cb := clipboard.new()
	mut editor := EditorModel.new(
		id:             5
		theme:          theme.dark_theme
		file_path:      file_path
		doc_id:         doc_id
		doc_controller: &ctrl
		cb:             &cb
		expand_tabs:    false
		tab_width:      4
	)
	editor.height = 7
	editor.cursor_pos = cursor.Pos.new(0, 15)
	editor.min_y = 0

	mut cmds := []tea.Cmd{}
	editor.execute_action(ChordAction{
		count:    1
		operator: none
		motion:   'zz'
	}, mut cmds)

	mut expected_min := editor.cursor_pos.y - editor.height / 2
	if expected_min < 0 {
		expected_min = 0
	}
	line_count := ctrl.line_count(doc_id)
	max_top := if line_count > editor.height { line_count - editor.height } else { 0 }
	if expected_min > max_top {
		expected_min = max_top
	}

	assert editor.min_y == expected_min
	assert editor.cursor_pos == cursor.Pos.new(0, 15)
}

fn test_editor_model_zz_with_count_moves_and_centers() {
	file_path := make_temp_file('zz_count', 40)
	defer { os.rm(file_path) or {} }

	mut ctrl := documents.Controller{}
	doc_id := ctrl.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut cb := clipboard.new()
	mut editor := EditorModel.new(
		id:             6
		theme:          theme.dark_theme
		file_path:      file_path
		doc_id:         doc_id
		doc_controller: &ctrl
		cb:             &cb
		expand_tabs:    false
		tab_width:      4
	)
	editor.height = 7
	editor.cursor_pos = cursor.Pos.new(0, 0)
	editor.min_y = 0

	mut cmds := []tea.Cmd{}
	editor.execute_action(ChordAction{
		count:    5
		operator: none
		motion:   'zz'
	}, mut cmds)

	assert editor.cursor_pos == cursor.Pos.new(0, 4)

	mut expected_min := editor.cursor_pos.y - editor.height / 2
	if expected_min < 0 {
		expected_min = 0
	}
	line_count := ctrl.line_count(doc_id)
	max_top := if line_count > editor.height { line_count - editor.height } else { 0 }
	if expected_min > max_top {
		expected_min = max_top
	}

	assert editor.min_y == expected_min
}
