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

fn make_x_motion_test_file(label string, content string) string {
	path := os.join_path(os.temp_dir(), 'lilly_x_motion_${label}_${time.now().unix_nano()}')
	os.write_file(path, content) or { panic('failed to write temp file: ${err}') }
	return path
}

fn test_x_deletes_char_under_cursor() {
	file_path := make_x_motion_test_file('basic', 'hello')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	c.delete_char_at(doc_id)
	assert c.get_line_bytes(doc_id, 0)? == [u8(`e`), `l`, `l`, `o`]
}

fn test_x_at_end_of_line_deletes_last_char_only() {
	file_path := make_x_motion_test_file('end_of_line', 'hi')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	c.move_cursor_right(doc_id)
	c.delete_char_at(doc_id)
	assert c.get_line_bytes(doc_id, 0)? == [u8(`h`)]
}

fn test_x_on_empty_line_does_not_join_next_line() {
	file_path := make_x_motion_test_file('empty_line', '\nworld')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	c.delete_char_at(doc_id)
	assert c.line_count(doc_id) == 2
	assert c.get_line_bytes(doc_id, 0)? == []
	assert c.get_line_bytes(doc_id, 1)? == [u8(`w`), `o`, `r`, `l`, `d`]
}

fn test_x_undo_restores_deleted_char() {
	file_path := make_x_motion_test_file('undo', 'hello')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	c.begin_undo_group(doc_id)
	c.delete_char_at(doc_id)
	c.commit_undo_group(doc_id)
	assert c.get_line_bytes(doc_id, 0)? == [u8(`e`), `l`, `l`, `o`]

	c.undo(doc_id)
	assert c.get_line_bytes(doc_id, 0)? == [u8(`h`), `e`, `l`, `l`, `o`]
}
