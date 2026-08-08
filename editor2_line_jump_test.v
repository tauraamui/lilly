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
import lib.cfg

fn make_zz_test_file(label string, line_count int) string {
	mut lines := []string{cap: line_count}
	for i in 0 .. line_count {
		lines << 'line ${i}'
	}
	path := os.join_path(os.temp_dir(), 'lilly_zz_${label}_${time.now().unix_nano()}')
	os.write_file(path, lines.join('\n')) or { panic('failed to write temp file: ${err}') }
	return path
}

fn test_execute_action_normal_zz_centers_current_line() {
	file_path := make_zz_test_file('center', 40)
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	mut m := EditorModel2{
		config:         EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:         doc_id
		doc_controller: &c
	}
	m.viewport_height = 7

	assert apply_motion(&c, doc_id, 'j', 15)

	_, switching_mode := m.execute_action_normal(ChordAction{
		count:  1
		motion: 'zz'
	})
	assert !switching_mode

	line, _ := c.cursor_line_and_x(doc_id)
	assert line == 15

	mut expected_top := int(line) - m.viewport_height / 2
	if expected_top < 0 {
		expected_top = 0
	}
	line_count := int(c.line_count(doc_id))
	max_top := if line_count > m.viewport_height { line_count - m.viewport_height } else { 0 }
	if expected_top > max_top {
		expected_top = max_top
	}

	assert m.top_line == expected_top
}

fn test_execute_action_normal_zz_with_count_moves_and_centers() {
	file_path := make_zz_test_file('count', 40)
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	mut m := EditorModel2{
		config:         EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:         doc_id
		doc_controller: &c
	}
	m.viewport_height = 7

	_, switching_mode := m.execute_action_normal(ChordAction{
		count:  5
		motion: 'zz'
	})
	assert !switching_mode

	line, _ := c.cursor_line_and_x(doc_id)
	assert line == 4 // 1-indexed count 5 -> zero-indexed line 4

	mut expected_top := int(line) - m.viewport_height / 2
	if expected_top < 0 {
		expected_top = 0
	}
	line_count := int(c.line_count(doc_id))
	max_top := if line_count > m.viewport_height { line_count - m.viewport_height } else { 0 }
	if expected_top > max_top {
		expected_top = max_top
	}

	assert m.top_line == expected_top
}

fn test_execute_action_normal_zz_clamps_to_document_end() {
	file_path := make_zz_test_file('clamp', 40)
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	mut m := EditorModel2{
		config:         EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:         doc_id
		doc_controller: &c
	}
	m.viewport_height = 7

	assert apply_motion(&c, doc_id, 'G', 1)

	_, switching_mode := m.execute_action_normal(ChordAction{
		count:  1
		motion: 'zz'
	})
	assert !switching_mode

	line_count := int(c.line_count(doc_id))
	expected_top := line_count - m.viewport_height
	assert m.top_line == expected_top
}

fn test_execute_action_normal_zz_with_large_viewport_sets_top_line_to_zero() {
	file_path := make_zz_test_file('large_view', 4)
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	mut m := EditorModel2{
		config:         EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:         doc_id
		doc_controller: &c
	}
	m.viewport_height = 20

	assert apply_motion(&c, doc_id, 'j', 2)

	_, switching_mode := m.execute_action_normal(ChordAction{
		count:  1
		motion: 'zz'
	})
	assert !switching_mode

	assert m.top_line == 0
}

fn test_normal_mode_ctrl_d_scrolls_and_moves_cursor() {
	file_path := make_zz_test_file('ctrl_d', 40)
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	mut m := EditorModel2{
		config:         EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:         doc_id
		doc_controller: &c
	}
	m.viewport_height = 10

	m.normal_mode_update(tea.KeyMsg{
		k_type: .special
		runes:  'ctrl+d'.runes()
	})

	assert m.top_line == 5
	line, _ := c.cursor_line_and_x(doc_id)
	assert line == 12
}

fn test_normal_mode_ctrl_u_scrolls_and_moves_cursor() {
	file_path := make_zz_test_file('ctrl_u', 40)
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	mut m := EditorModel2{
		config:         EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:         doc_id
		doc_controller: &c
	}
	m.viewport_height = 10
	m.top_line = 2

	assert apply_motion(&c, doc_id, 'j', 3)

	m.normal_mode_update(tea.KeyMsg{
		k_type: .special
		runes:  'ctrl+u'.runes()
	})

	assert m.top_line == 0
	line, _ := c.cursor_line_and_x(doc_id)
	assert line == 2
}

fn test_normal_mode_ctrl_d_clamps_at_document_end() {
	file_path := make_zz_test_file('ctrl_d_clamp', 12)
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	mut m := EditorModel2{
		config:         EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:         doc_id
		doc_controller: &c
	}
	m.viewport_height = 10

	m.normal_mode_update(tea.KeyMsg{
		k_type: .special
		runes:  'ctrl+d'.runes()
	})

	assert m.top_line == 2
	line, _ := c.cursor_line_and_x(doc_id)
	assert line == 11
}
