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

import io
import os
import lib.buffers
import lib.nanoid
import lib.documents.cursor

@[heap]
pub struct Controller2 {
mut:
	docs map[nanoid.ID]buffers.TextBuffer = map[nanoid.ID]buffers.TextBuffer{}
}

pub fn Controller2.new() Controller2 {
	return Controller2{
		docs: map[nanoid.ID]buffers.TextBuffer{}
	}
}

pub fn (mut dc Controller2) open_document(path string) !nanoid.ID {
	mut file := os.open(path) or { return error('failed to open ${path}: ${err}') }
	defer {
		file.close()
	}
	return dc.load_document_from_reader(path, mut file)
}

pub fn (mut dc Controller2) load_document_from_reader(path string, mut r io.Reader) !nanoid.ID {
	doc_id := nanoid.simple_with_seed(path)
	if _ := dc.docs[doc_id] { // if ID is present we already have a document with the same path open
		return doc_id
	}
	mut text_buf := buffers.TextBuffer.new(mut r) or { return err }
	dc.docs[doc_id] = text_buf
	return doc_id
}

pub fn (mut dc Controller2) insert(doc_id nanoid.ID, c u8) {
	dc.docs[doc_id].insert(c)
}

pub fn (mut dc Controller2) insert_rune(doc_id nanoid.ID, cr rune) {
	dc.docs[doc_id].insert_rune(cr)
}

pub fn (mut dc Controller2) backspace(doc_id nanoid.ID) {
	dc.docs[doc_id].backspace()
}

pub fn (mut dc Controller2) delete(doc_id nanoid.ID) {
	dc.docs[doc_id].delete()
}

pub fn (mut dc Controller2) delete_char_at(doc_id nanoid.ID) {
	dc.docs[doc_id].delete_char_at()
}

pub fn (mut dc Controller2) delete_line(doc_id nanoid.ID, y u64) {
	dc.docs[doc_id].delete_line(y)
}

pub fn (mut dc Controller2) delete_range(doc_id nanoid.ID, r cursor.Range) {
	dc.docs[doc_id].delete_range(u64(r.start.y), u64(r.start.x), u64(r.end.y), u64(r.end.x))
}

pub fn (mut dc Controller2) begin_undo_group(doc_id nanoid.ID) {
	dc.docs[doc_id].begin_undo_group()
}

pub fn (mut dc Controller2) commit_undo_group(doc_id nanoid.ID) {
	dc.docs[doc_id].commit_undo_group()
}

pub fn (mut dc Controller2) undo(doc_id nanoid.ID) {
	dc.docs[doc_id].undo()
}

pub fn (mut dc Controller2) redo(doc_id nanoid.ID) {
	dc.docs[doc_id].redo()
}

pub fn (mut dc Controller2) move_cursor_left(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_left()
}

pub fn (mut dc Controller2) move_cursor_right(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_right()
}

// internal_move_cursor_left/right are for automatic clamping only (e.g.
// pulling the cursor back onto the last char in normal mode) - they don't
// reset the sticky goal column the way real user-triggered moves do, so
// don't wire these to actual key input.
pub fn (mut dc Controller2) internal_move_cursor_left(doc_id nanoid.ID) {
	dc.docs[doc_id].internal_move_cursor_left()
}

pub fn (mut dc Controller2) internal_move_cursor_right(doc_id nanoid.ID) {
	dc.docs[doc_id].internal_move_cursor_right()
}

pub fn (mut dc Controller2) move_cursor_up(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_up()
}

pub fn (mut dc Controller2) move_cursor_down(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_down()
}

pub fn (mut dc Controller2) move_cursor_to_previous_blank_line(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_to_previous_blank_line()
}

pub fn (mut dc Controller2) move_cursor_to_next_blank_line(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_to_next_blank_line()
}

pub fn (mut dc Controller2) move_cursor_to_next_word_start(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_to_next_word_start()
}

pub fn (mut dc Controller2) move_cursor_to_previous_word_start(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_to_previous_word_start()
}

pub fn (mut dc Controller2) move_cursor_to_next_word_end(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_to_next_word_end()
}

pub fn (mut dc Controller2) move_cursor_to_previous_word_end(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_to_previous_word_end()
}

pub fn (mut dc Controller2) move_cursor_to_next_big_word_start(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_to_next_big_word_start()
}

pub fn (mut dc Controller2) jump_cursor_to_line_end(doc_id nanoid.ID) {
	dc.docs[doc_id].jump_cursor_to_line_end()
}

pub fn (mut dc Controller2) jump_cursor_to_line_start(doc_id nanoid.ID) {
	dc.docs[doc_id].jump_cursor_to_line_start()
}

pub fn (mut dc Controller2) jump_cursor_to_text_start(doc_id nanoid.ID) {
	dc.docs[doc_id].jump_cursor_to_text_start()
}

pub fn (mut dc Controller2) jump_cursor_to_line(doc_id nanoid.ID, y u64) {
	dc.docs[doc_id].jump_cursor_to_line(y)
}

pub fn (mut dc Controller2) write_to_disk(doc_id nanoid.ID, target string) ! {
	dc.docs[doc_id].write_to_path(target)!
}

pub fn (dc Controller2) resolve_prev_line_whitespace_prefix(doc_id nanoid.ID) []u8 {
	return dc.docs[doc_id].resolve_prev_line_whitespace_prefix()
}

pub fn (mut dc Controller2) get_line_bytes(doc_id nanoid.ID, y u64) ?[]u8 {
	return dc.docs[doc_id].get_line_bytes(y)
}

pub fn (dc Controller2) cursor_line_and_x(doc_id nanoid.ID) (u64, u64) {
	return dc.docs[doc_id].cursor_line_and_x()
}

pub fn (dc Controller2) line_count(doc_id nanoid.ID) u64 {
	return dc.docs[doc_id].line_count()
}
