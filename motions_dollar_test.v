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
import lib.documents.cursor

fn make_dollar_test_file(label string, content string) string {
	path := os.join_path(os.temp_dir(), 'lilly_dollar_${label}_${time.now().unix_nano()}')
	os.write_file(path, content) or { panic('failed to write temp file: ${err}') }
	return path
}

fn test_apply_motion_dollar_moves_to_last_char_of_line() {
	file_path := make_dollar_test_file('basic', 'hello\nworld')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	assert apply_motion(&c, doc_id, '$', 1)
	line, col := c.cursor_line_and_x(doc_id)
	assert line == 0
	assert col == 4 // 'o' in "hello", not one past it
}

fn test_apply_motion_dollar_on_empty_line_stays_put() {
	file_path := make_dollar_test_file('empty_line', '\nworld')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	assert apply_motion(&c, doc_id, '$', 1)
	line, col := c.cursor_line_and_x(doc_id)
	assert line == 0
	assert col == 0
}

fn test_apply_motion_dollar_with_count_moves_down_first() {
	file_path := make_dollar_test_file('count', 'aa\nbbbb\nc')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	// 3$ == go down 2 lines, then to the end of THAT line, not
	// "jump to end of line" repeated three times.
	assert apply_motion(&c, doc_id, '$', 3)
	line, col := c.cursor_line_and_x(doc_id)
	assert line == 2
	assert col == 0 // only char on line 2 is 'c'
}

fn test_apply_motion_dollar_with_count_clamps_at_last_line() {
	file_path := make_dollar_test_file('clamp', 'aa\nbbbb')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	assert apply_motion(&c, doc_id, '$', 10)
	line, col := c.cursor_line_and_x(doc_id)
	assert line == 1
	assert col == 3 // last char of "bbbb" (clamped at last line)
}

fn test_motion_range_dollar_is_inclusive() {
	file_path := make_dollar_test_file('range', 'hello')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	r := motion_range(&c, doc_id, '$', 1) or { panic('expected a range') }
	assert r.start == cursor.Pos.new(0, 0)
	assert r.end == cursor.Pos.new(5, 0) // one past the last char, for exclusive delete_range
}

fn test_apply_operator_d_dollar_deletes_through_last_char() {
	file_path := make_dollar_test_file('delete', 'hello\nworld')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	r := motion_range(&c, doc_id, '$', 1) or { panic('expected a range') }
	assert apply_operator(&c, doc_id, `d`, r)

	assert c.get_line_bytes(doc_id, 0)? == []
	assert c.get_line_bytes(doc_id, 1)? == [u8(`w`), `o`, `r`, `l`, `d`]
}

fn test_apply_operator_d_dollar_on_empty_line_is_noop() {
	file_path := make_dollar_test_file('delete_empty', '\nworld')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	r := motion_range(&c, doc_id, '$', 1) or { panic('expected a range') }
	assert apply_operator(&c, doc_id, `d`, r)

	assert c.get_line_bytes(doc_id, 0)? == []
	assert c.get_line_bytes(doc_id, 1)? == [u8(`w`), `o`, `r`, `l`, `d`]
}
