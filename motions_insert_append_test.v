// Copyright 2026 The Lilly Edtior contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

module main

import os
import time
import lib.documents
import lib.cfg

fn make_insert_append_test_file(label string, content string) string {
	path := os.join_path(os.temp_dir(), 'lilly_insert_append_${label}_${time.now().unix_nano()}')
	os.write_file(path, content) or { panic('failed to write temp file: ${err}') }
	return path
}

fn test_execute_action_normal_capital_i_moves_to_text_start_and_switches_to_insert() {
	file_path := make_insert_append_test_file('capital_i', '   hello')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	mut m := EditorModel2{
		config:         EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:         doc_id
		doc_controller: &c
	}

	assert apply_motion(&c, doc_id, '$', 1)

	_, switching_mode := m.execute_action_normal(ChordAction{
		count:  1
		motion: 'I'
	})
	assert switching_mode

	line, col := c.cursor_line_and_x(doc_id)
	assert line == 0
	assert col == 3 // 'h' in "hello"
}

fn test_execute_action_normal_capital_a_moves_to_line_end_and_switches_to_insert() {
	file_path := make_insert_append_test_file('capital_a', 'hello')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	mut m := EditorModel2{
		config:         EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:         doc_id
		doc_controller: &c
	}

	_, switching_mode := m.execute_action_normal(ChordAction{
		count:  1
		motion: 'A'
	})
	assert switching_mode

	line, col := c.cursor_line_and_x(doc_id)
	assert line == 0
	assert col == 5 // one past the last character of "hello"
}
