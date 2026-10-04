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

module documents

import os

/*
fn test_controller_backspace_on_given_document() {
	mock_doc_id := 1
	mut c := Controller2{
		docs: { mock_doc_id: buffers.TextBuffer.new() or { panic(err) } }
	}
	c.insert(mock_doc_id, u8(`a`))
}
*/

fn test_controller_open_document_from_path() {
	file_path := os.join_path(os.temp_dir(), 'test_LF.txt')
	defer { os.rm(file_path) or { println('failed to delete ${file_path}: ${err}') } }
	os.write_file(file_path, 'hello\nWoRlD<')!

	mut c := Controller2{}
	doc_id := c.open_document(file_path)!
	assert doc_id != ''
	assert c.get_line_bytes(doc_id, 0)? == [u8(`h`), `e`, `l`, `l`, `o`]
	assert c.get_line_bytes(doc_id, 1)? == [u8(`W`), `o`, `R`, `l`, `D`, `<`]
}

fn test_controller_open_document_from_path_subsequent_edits() {
	file_path := os.join_path(os.temp_dir(), 'test_LF.txt')
	defer { os.rm(file_path) or { println('failed to delete ${file_path}: ${err}') } }
	os.write_file(file_path, 'hello\nWoRlD<')!

	mut c := Controller2{}
	doc_id := c.open_document(file_path)!
	assert doc_id != ''
	assert c.get_line_bytes(doc_id, 0)? == [u8(`h`), `e`, `l`, `l`, `o`]
	assert c.get_line_bytes(doc_id, 1)? == [u8(`W`), `o`, `R`, `l`, `D`, `<`]

	c.backspace(doc_id)
	assert c.get_line_bytes(doc_id, 0)? == [u8(`h`), `e`, `l`, `l`, `o`]
	assert c.get_line_bytes(doc_id, 1)? == [u8(`W`), `o`, `R`, `l`, `D`, `<`]

	c.move_cursor_right(doc_id)
	c.move_cursor_right(doc_id)
	c.backspace(doc_id)
	assert c.get_line_bytes(doc_id, 0)? == [u8(`h`), `l`, `l`, `o`]
	assert c.get_line_bytes(doc_id, 1)? == [u8(`W`), `o`, `R`, `l`, `D`, `<`]
}

fn test_controller_insert_after_load_goes_to_start() {
	file_path := os.join_path(os.temp_dir(), 'test_LF_insert_start.txt')
	defer { os.rm(file_path) or { println('failed to delete ${file_path}: ${err}') } }
	os.write_file(file_path, 'hello\nWoRlD<')!

	mut c := Controller2{}
	doc_id := c.open_document(file_path)!
	c.insert(doc_id, u8(`>`))

	assert c.get_line_bytes(doc_id, 0)? == [u8(`>`), `h`, `e`, `l`, `l`, `o`]
	assert c.get_line_bytes(doc_id, 1)? == [u8(`W`), `o`, `R`, `l`, `D`, `<`]
}

fn test_controller_document_is_clean_until_edited() {
	file_path := os.join_path(os.temp_dir(), 'test_dirty_clean.txt')
	defer { os.rm(file_path) or { println('failed to delete ${file_path}: ${err}') } }
	os.write_file(file_path, 'hello\nWoRlD<')!

	mut c := Controller2{}
	doc_id := c.open_document(file_path)!
	assert !c.is_dirty(doc_id)

	// a motion is not an edit
	c.move_cursor_right(doc_id)
	assert !c.is_dirty(doc_id)

	c.insert(doc_id, u8(`>`))
	assert c.is_dirty(doc_id)
}

fn test_controller_write_to_disk_marks_document_clean() {
	file_path := os.join_path(os.temp_dir(), 'test_dirty_write.txt')
	defer { os.rm(file_path) or { println('failed to delete ${file_path}: ${err}') } }
	os.write_file(file_path, 'hello')!

	mut c := Controller2{}
	doc_id := c.open_document(file_path)!
	c.insert(doc_id, u8(`>`))
	assert c.is_dirty(doc_id)

	c.write_to_disk(doc_id, file_path)!
	assert !c.is_dirty(doc_id)

	c.insert(doc_id, u8(`<`))
	assert c.is_dirty(doc_id)
}

fn test_controller_mark_clean_forgets_edits_without_writing() {
	file_path := os.join_path(os.temp_dir(), 'test_dirty_discard.txt')
	defer { os.rm(file_path) or { println('failed to delete ${file_path}: ${err}') } }
	os.write_file(file_path, 'hello')!

	mut c := Controller2{}
	doc_id := c.open_document(file_path)!
	c.insert(doc_id, u8(`>`))
	c.mark_clean(doc_id)

	assert !c.is_dirty(doc_id)
	// the edit is forgotten, not undone: nothing was written either way
	assert os.read_file(file_path)! == 'hello'
}

fn test_controller_unknown_document_reads_clean() {
	mut c := Controller2{}
	assert !c.is_dirty('no-such-document')
}

fn test_controller_close_unreferenced_drops_only_documents_not_named() {
	mut paths := []string{}
	for name in ['test_sweep_a.txt', 'test_sweep_b.txt', 'test_sweep_c.txt'] {
		path := os.join_path(os.temp_dir(), name)
		os.write_file(path, 'contents of ${name}')!
		paths << path
	}
	defer {
		for path in paths {
			os.rm(path) or { println('failed to delete ${path}: ${err}') }
		}
	}

	mut c := Controller2{}
	a := c.open_document(paths[0])!
	b := c.open_document(paths[1])!
	cc := c.open_document(paths[2])!
	assert c.footprint().doc_count == 3

	assert a != b && b != cc
	assert c.close_unreferenced([a, cc]) == 1
	assert c.footprint().doc_count == 2
	assert c.get_line_bytes(a, 0)? == 'contents of test_sweep_a.txt'.bytes()
	assert c.get_line_bytes(cc, 0)? == 'contents of test_sweep_c.txt'.bytes()

	// sweeping with nothing live closes everything
	assert c.close_unreferenced([]) == 2
	assert c.footprint().doc_count == 0
}

fn test_controller_close_unreferenced_drops_the_dirty_flag_with_the_document() {
	file_path := os.join_path(os.temp_dir(), 'test_sweep_dirty.txt')
	defer { os.rm(file_path) or { println('failed to delete ${file_path}: ${err}') } }
	os.write_file(file_path, 'hello')!

	mut c := Controller2{}
	doc_id := c.open_document(file_path)!
	c.insert(doc_id, u8(`>`))
	assert c.is_dirty(doc_id)

	assert c.close_unreferenced([]) == 1
	// re-opening the same path yields the same id, which must not come back
	// still flagged from its previous life
	reopened := c.open_document(file_path)!
	assert reopened == doc_id
	assert !c.is_dirty(reopened)
}

fn test_controller_reopening_an_open_path_reuses_the_document() {
	file_path := os.join_path(os.temp_dir(), 'test_sweep_reopen.txt')
	defer { os.rm(file_path) or { println('failed to delete ${file_path}: ${err}') } }
	os.write_file(file_path, 'hello')!

	mut c := Controller2{}
	first := c.open_document(file_path)!
	c.insert(first, u8(`>`))
	second := c.open_document(file_path)!

	assert first == second
	assert c.footprint().doc_count == 1
}
