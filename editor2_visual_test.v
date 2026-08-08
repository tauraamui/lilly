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
import lib.documents
import lib.cfg

fn make_visual_test_file(label string, content string) string {
	path := os.join_path(os.temp_dir(), 'lilly_visual_${label}_${time.now().unix_nano()}')
	os.write_file(path, content) or { panic('failed to write temp file: ${err}') }
	return path
}

fn test_current_visual_range_includes_char_under_cursor() {
	file_path := make_visual_test_file('range', 'This is the first line of')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	mut m := EditorModel2{
		config:         EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:         doc_id
		doc_controller: &c
	}

	// select "is the first line" - start at the 'i' of "is" (col 5), end at
	// the 'e' of "line" (col 21)
	for _ in 0 .. 5 {
		c.move_cursor_right(doc_id)
	}
	line, col := c.cursor_line_and_x(doc_id)
	m.visual_sel_start_line = line
	m.visual_sel_start_col = col

	for _ in 0 .. 16 {
		c.move_cursor_right(doc_id)
	}

	r := m.current_visual_range() or { panic('expected a range') }
	assert apply_operator(&c, doc_id, `d`, r)

	assert c.get_line_bytes(doc_id, 0)? == 'This  of'.bytes()
}

fn test_current_visual_range_handles_reversed_selection() {
	file_path := make_visual_test_file('reversed', 'This is the first line of')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	mut m := EditorModel2{
		config:         EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:         doc_id
		doc_controller: &c
	}

	// selection started at the 'e' of "line" (col 21) and cursor moved
	// backwards to the 'i' of "is" (col 5)
	for _ in 0 .. 21 {
		c.move_cursor_right(doc_id)
	}
	line, col := c.cursor_line_and_x(doc_id)
	m.visual_sel_start_line = line
	m.visual_sel_start_col = col

	for _ in 0 .. 16 {
		c.move_cursor_left(doc_id)
	}

	r := m.current_visual_range() or { panic('expected a range') }
	assert apply_operator(&c, doc_id, `d`, r)

	assert c.get_line_bytes(doc_id, 0)? == 'This  of'.bytes()
}

fn test_apply_linewise_operator_deletes_full_selected_lines() {
	file_path := make_visual_test_file('linewise', 'one\ntwo\nthree\nfour')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	mut m := EditorModel2{
		config:          EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:          doc_id
		doc_controller:  &c
		visual_linewise: true
	}

	c.move_cursor_down(doc_id) // land on "two"
	line, col := c.cursor_line_and_x(doc_id)
	m.visual_sel_start_line = line
	m.visual_sel_start_col = col

	c.move_cursor_down(doc_id) // extend selection down to "three"

	m.apply_linewise_operator(`d`)

	assert c.line_count(doc_id) == 2
	assert c.get_line_bytes(doc_id, 0)? == 'one'.bytes()
	assert c.get_line_bytes(doc_id, 1)? == 'four'.bytes()
}

fn test_execute_action_visual_delete_closes_undo_group_charwise() {
	file_path := make_visual_test_file('undo_charwise', 'This is the first line of')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	mut m := EditorModel2{
		config:         EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:         doc_id
		doc_controller: &c
	}

	for _ in 0 .. 5 {
		c.move_cursor_right(doc_id)
	}
	line, col := c.cursor_line_and_x(doc_id)
	m.visual_sel_start_line = line
	m.visual_sel_start_col = col

	for _ in 0 .. 16 {
		c.move_cursor_right(doc_id)
	}

	m.execute_action_visual(ChordAction{ operator: ?u8(`d`) })

	assert c.get_line_bytes(doc_id, 0)? == 'This  of'.bytes()

	// a closed undo group must be independently undoable - it must not still
	// be open and waiting to absorb whatever the next edit happens to be
	c.undo(doc_id)
	assert c.get_line_bytes(doc_id, 0)? == 'This is the first line of'.bytes()
}

fn test_execute_action_visual_delete_closes_undo_group_linewise() {
	file_path := make_visual_test_file('undo_linewise', 'one\ntwo\nthree\nfour')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	mut m := EditorModel2{
		config:          EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:          doc_id
		doc_controller:  &c
		visual_linewise: true
	}

	c.move_cursor_down(doc_id) // land on "two"
	line, col := c.cursor_line_and_x(doc_id)
	m.visual_sel_start_line = line
	m.visual_sel_start_col = col

	c.move_cursor_down(doc_id) // extend selection down to "three"

	m.execute_action_visual(ChordAction{ operator: ?u8(`d`) })

	assert c.line_count(doc_id) == 2

	c.undo(doc_id)
	assert c.line_count(doc_id) == 4
	assert c.get_line_bytes(doc_id, 0)? == 'one'.bytes()
	assert c.get_line_bytes(doc_id, 1)? == 'two'.bytes()
	assert c.get_line_bytes(doc_id, 2)? == 'three'.bytes()
	assert c.get_line_bytes(doc_id, 3)? == 'four'.bytes()
}

fn test_apply_linewise_operator_handles_reversed_selection() {
	file_path := make_visual_test_file('linewise_reversed', 'one\ntwo\nthree\nfour')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	mut m := EditorModel2{
		config:          EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:          doc_id
		doc_controller:  &c
		visual_linewise: true
	}

	// selection started on "three" and cursor moved back up to "two"
	c.move_cursor_down(doc_id)
	c.move_cursor_down(doc_id)
	line, col := c.cursor_line_and_x(doc_id)
	m.visual_sel_start_line = line
	m.visual_sel_start_col = col

	c.move_cursor_up(doc_id)

	m.apply_linewise_operator(`d`)

	assert c.line_count(doc_id) == 2
	assert c.get_line_bytes(doc_id, 0)? == 'one'.bytes()
	assert c.get_line_bytes(doc_id, 1)? == 'four'.bytes()
}
