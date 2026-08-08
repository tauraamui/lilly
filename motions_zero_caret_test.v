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

fn make_zero_caret_test_file(label string, content string) string {
	path := os.join_path(os.temp_dir(), 'lilly_zero_caret_${label}_${time.now().unix_nano()}')
	os.write_file(path, content) or { panic('failed to write temp file: ${err}') }
	return path
}

fn test_apply_motion_zero_moves_to_column_zero() {
	file_path := make_zero_caret_test_file('basic', '   hello')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	assert apply_motion(&c, doc_id, '$', 1)
	assert apply_motion(&c, doc_id, '0', 1)
	line, col := c.cursor_line_and_x(doc_id)
	assert line == 0
	assert col == 0
}

fn test_apply_motion_zero_on_empty_line_stays_put() {
	file_path := make_zero_caret_test_file('empty_line', '\nworld')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	assert apply_motion(&c, doc_id, '0', 1)
	line, col := c.cursor_line_and_x(doc_id)
	assert line == 0
	assert col == 0
}

fn test_apply_motion_caret_moves_to_first_non_blank() {
	file_path := make_zero_caret_test_file('basic', '   hello')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	assert apply_motion(&c, doc_id, '^', 1)
	line, col := c.cursor_line_and_x(doc_id)
	assert line == 0
	assert col == 3 // 'h' in "hello"
}

fn test_apply_motion_caret_with_no_leading_whitespace_matches_zero() {
	file_path := make_zero_caret_test_file('no_ws', 'hello')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	assert apply_motion(&c, doc_id, '$', 1)
	assert apply_motion(&c, doc_id, '^', 1)
	line, col := c.cursor_line_and_x(doc_id)
	assert line == 0
	assert col == 0
}

fn test_apply_motion_caret_on_all_whitespace_line_stays_put() {
	file_path := make_zero_caret_test_file('all_ws', '   \nworld')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	assert apply_motion(&c, doc_id, '$', 1)
	_, before_col := c.cursor_line_and_x(doc_id)

	assert apply_motion(&c, doc_id, '^', 1)
	line, col := c.cursor_line_and_x(doc_id)
	assert line == 0
	assert col == before_col
}

fn test_apply_motion_caret_on_empty_line_stays_put() {
	file_path := make_zero_caret_test_file('empty_line', '\nworld')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	assert apply_motion(&c, doc_id, '^', 1)
	line, col := c.cursor_line_and_x(doc_id)
	assert line == 0
	assert col == 0
}
