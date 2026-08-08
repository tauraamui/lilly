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

fn make_gg_g_test_file(label string, content string) string {
	path := os.join_path(os.temp_dir(), 'lilly_gg_g_${label}_${time.now().unix_nano()}')
	os.write_file(path, content) or { panic('failed to write temp file: ${err}') }
	return path
}

fn test_apply_motion_gg_moves_to_first_line_text_start() {
	file_path := make_gg_g_test_file('basic', 'hello\n  world\nfoo')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	assert apply_motion(&c, doc_id, 'j', 2) // start somewhere down in the doc
	assert apply_motion(&c, doc_id, 'gg', 1)
	line, col := c.cursor_line_and_x(doc_id)
	assert line == 0
	assert col == 0
}

fn test_apply_motion_gg_with_count_goes_to_that_line_first_non_blank() {
	file_path := make_gg_g_test_file('count', 'hello\n  world\nfoo')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	assert apply_motion(&c, doc_id, 'gg', 2)
	line, col := c.cursor_line_and_x(doc_id)
	assert line == 1
	assert col == 2 // first non-blank char of "  world"
}

fn test_apply_motion_gg_with_count_clamps_at_last_line() {
	file_path := make_gg_g_test_file('clamp', 'aa\nbb')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	assert apply_motion(&c, doc_id, 'gg', 10)
	line, _ := c.cursor_line_and_x(doc_id)
	assert line == 1
}

fn test_apply_motion_upper_g_moves_to_last_line_text_start() {
	file_path := make_gg_g_test_file('last', 'hello\n  world\n  foo')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	assert apply_motion(&c, doc_id, 'G', 1)
	line, col := c.cursor_line_and_x(doc_id)
	assert line == 2
	assert col == 2 // first non-blank char of "  foo"
}

fn test_apply_motion_upper_g_with_count_goes_to_that_line() {
	file_path := make_gg_g_test_file('count_upper', 'hello\n  world\nfoo')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	assert apply_motion(&c, doc_id, 'G', 2)
	line, col := c.cursor_line_and_x(doc_id)
	assert line == 1
	assert col == 2 // first non-blank char of "  world"
}
