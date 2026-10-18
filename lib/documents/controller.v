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
pub struct Controller {
mut:
	docs map[nanoid.ID]buffers.TextBuffer = map[nanoid.ID]buffers.TextBuffer{}
	// dirty holds the ids of documents edited since they were last written.
	//
	// Deliberately conservative: every edit sets it and only a successful
	// write clears it, so undoing back to the on-disk content still reports
	// dirty. Tracking that exactly would mean marking a save point in the undo
	// chain and keeping it valid across undo, redo and chain breaks, and the
	// cost of being wrong the other way is a discarded edit.
	dirty map[nanoid.ID]bool = map[nanoid.ID]bool{}
}

pub fn Controller.new() Controller {
	return Controller{
		docs:  map[nanoid.ID]buffers.TextBuffer{}
		dirty: map[nanoid.ID]bool{}
	}
}

pub fn (mut dc Controller) open_document(path string) !nanoid.ID {
	mut file := os.open(path) or { return error('failed to open ${path}: ${err}') }
	defer {
		file.close()
	}
	return dc.load_document_sized(path, mut file, os.file_size(path))
}

pub fn (mut dc Controller) load_document_from_reader(path string, mut r io.Reader) !nanoid.ID {
	return dc.load_document_sized(path, mut r, 0)
}

fn (mut dc Controller) load_document_sized(path string, mut r io.Reader, size_hint u64) !nanoid.ID {
	doc_id := nanoid.simple_with_seed(path)
	if _ := dc.docs[doc_id] { // if ID is present we already have a document with the same path open
		return doc_id
	}
	mut text_buf := buffers.TextBuffer.new_with_size_hint(mut r, size_hint) or { return err }
	dc.docs[doc_id] = text_buf
	return doc_id
}

pub fn (mut dc Controller) insert(doc_id nanoid.ID, c u8) {
	dc.dirty[doc_id] = true
	dc.docs[doc_id].insert(c)
}

pub fn (mut dc Controller) insert_rune(doc_id nanoid.ID, cr rune) {
	dc.dirty[doc_id] = true
	dc.docs[doc_id].insert_rune(cr)
}

pub fn (mut dc Controller) insert_string(doc_id nanoid.ID, s string) {
	dc.dirty[doc_id] = true
	for cr in s.runes() {
		dc.docs[doc_id].insert_rune(cr)
	}
}

pub fn (mut dc Controller) backspace(doc_id nanoid.ID) {
	dc.dirty[doc_id] = true
	dc.docs[doc_id].backspace()
}

pub fn (mut dc Controller) delete(doc_id nanoid.ID) {
	dc.dirty[doc_id] = true
	dc.docs[doc_id].delete()
}

// delete_char_at deletes the character under the cursor, and reports
// whether there was one to delete
pub fn (mut dc Controller) delete_char_at(doc_id nanoid.ID) bool {
	dc.dirty[doc_id] = true
	return dc.docs[doc_id].delete_char_at()
}

pub fn (mut dc Controller) delete_line(doc_id nanoid.ID, y u64) {
	dc.dirty[doc_id] = true
	dc.docs[doc_id].delete_line(y)
}

pub fn (mut dc Controller) delete_range(doc_id nanoid.ID, r cursor.Range) {
	dc.dirty[doc_id] = true
	dc.docs[doc_id].delete_range(u64(r.start.y), u64(r.start.x), u64(r.end.y), u64(r.end.x))
}

pub fn (mut dc Controller) begin_undo_group(doc_id nanoid.ID) {
	dc.docs[doc_id].begin_undo_group()
}

pub fn (mut dc Controller) commit_undo_group(doc_id nanoid.ID) {
	dc.docs[doc_id].commit_undo_group()
}

pub fn (mut dc Controller) undo(doc_id nanoid.ID) {
	dc.dirty[doc_id] = true
	dc.docs[doc_id].undo()
}

pub fn (mut dc Controller) redo(doc_id nanoid.ID) {
	dc.dirty[doc_id] = true
	dc.docs[doc_id].redo()
}

// line_changes_since reports which lines of the document changed after
// generation `gen`, for readers keeping per-line state. Pass 0 the first time.
pub fn (mut dc Controller) line_changes_since(doc_id nanoid.ID, gen u64) buffers.LineChanges {
	return dc.docs[doc_id].line_changes_since(gen)
}

pub fn (mut dc Controller) move_cursor_left(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_left()
}

pub fn (mut dc Controller) move_cursor_right(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_right()
}

// internal_move_cursor_left/right are for automatic clamping only (e.g.
// pulling the cursor back onto the last char in normal mode) - they don't
// reset the sticky goal column the way real user-triggered moves do, so
// don't wire these to actual key input.
pub fn (mut dc Controller) internal_move_cursor_left(doc_id nanoid.ID) {
	dc.docs[doc_id].internal_move_cursor_left()
}

pub fn (mut dc Controller) internal_move_cursor_right(doc_id nanoid.ID) {
	dc.docs[doc_id].internal_move_cursor_right()
}

pub fn (mut dc Controller) move_cursor_up(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_up()
}

pub fn (mut dc Controller) move_cursor_down(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_down()
}

// move_cursor_lines moves the cursor `n` lines down, or up for a negative `n`,
// as that many presses of j or k would
pub fn (mut dc Controller) move_cursor_lines(doc_id nanoid.ID, n int) {
	dc.docs[doc_id].move_cursor_lines(n)
}

pub fn (mut dc Controller) move_cursor_to_previous_blank_line(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_to_previous_blank_line()
}

pub fn (mut dc Controller) move_cursor_to_next_blank_line(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_to_next_blank_line()
}

pub fn (mut dc Controller) move_cursor_to_next_word_start(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_to_next_word_start()
}

pub fn (mut dc Controller) move_cursor_to_previous_word_start(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_to_previous_word_start()
}

pub fn (mut dc Controller) move_cursor_to_next_word_end(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_to_next_word_end()
}

pub fn (mut dc Controller) move_cursor_to_previous_word_end(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_to_previous_word_end()
}

pub fn (mut dc Controller) move_cursor_to_next_big_word_start(doc_id nanoid.ID) {
	dc.docs[doc_id].move_cursor_to_next_big_word_start()
}

pub fn (mut dc Controller) jump_cursor_to_line_end(doc_id nanoid.ID) {
	dc.docs[doc_id].jump_cursor_to_line_end()
}

pub fn (mut dc Controller) jump_cursor_to_line_start(doc_id nanoid.ID) {
	dc.docs[doc_id].jump_cursor_to_line_start()
}

pub fn (mut dc Controller) jump_cursor_to_text_start(doc_id nanoid.ID) {
	dc.docs[doc_id].jump_cursor_to_text_start()
}

pub fn (mut dc Controller) jump_cursor_to_line(doc_id nanoid.ID, y u64) {
	dc.docs[doc_id].jump_cursor_to_line(y)
}

pub fn (mut dc Controller) write_to_disk(doc_id nanoid.ID, target string) ! {
	dc.docs[doc_id].write_to_path(target)!
	dc.dirty.delete(doc_id)
}

// mark_clean forgets that a document has unwritten edits, without writing
// them. For a caller that has asked and been told to discard: the edits go
// when the document does, and the flag has to go with them or the next close
// would ask about them again.
pub fn (mut dc Controller) mark_clean(doc_id nanoid.ID) {
	dc.dirty.delete(doc_id)
}

// is_dirty reports whether this document has been edited since it was last
// written to disk. An id that is not open reads clean.
pub fn (dc Controller) is_dirty(doc_id nanoid.ID) bool {
	return dc.dirty[doc_id]
}

// close_unreferenced drops every open document whose id is not in live_doc_ids,
// and reports how many it closed.
//
// A document outlives the editor that opened it: splitting gives two editors
// one id, and opening a file over an editor retires that editor while the
// document it showed stays open. So a document is only releasable once no
// editor names it, which the caller establishes by passing the ids its
// surviving editors hold.
//
// Sweeping the whole map is deliberate in place of a reference count per
// document: it is less state, it cannot drift out of step with the editors
// that are actually open, and the map holds one entry per open file.
pub fn (mut dc Controller) close_unreferenced(live_doc_ids []nanoid.ID) int {
	mut stale := []nanoid.ID{}
	for doc_id, _ in dc.docs {
		if doc_id !in live_doc_ids {
			stale << doc_id
		}
	}
	for doc_id in stale {
		// cleared before the key is removed, and not merely deleted: V's map
		// delete drops the key but leaves the value's bytes in the map's
		// backing store, so everything the value points at stays reachable and
		// the collector keeps a document alive long after it was closed.
		dc.docs[doc_id].release()
		dc.docs.delete(doc_id)
		dc.dirty.delete(doc_id)
	}
	return stale.len
}

pub fn (dc Controller) resolve_prev_line_whitespace_prefix(doc_id nanoid.ID) []u8 {
	return dc.docs[doc_id].resolve_prev_line_whitespace_prefix()
}

pub fn (mut dc Controller) get_line_bytes(doc_id nanoid.ID, y u64) ?[]u8 {
	return dc.docs[doc_id].get_line_bytes(y)
}

// line_runes_into decodes line `y` into `out`, with `scratch` holding its
// bytes on the way, allocating nothing once the two have grown. It returns
// false past the last line.
pub fn (mut dc Controller) line_runes_into(doc_id nanoid.ID, y u64, mut scratch []u8, mut out []rune) bool {
	return dc.docs[doc_id].line_runes_into(y, mut scratch, mut out)
}

pub fn (dc Controller) cursor_line_and_x(doc_id nanoid.ID) (u64, u64) {
	return dc.docs[doc_id].cursor_line_and_x()
}

pub fn (dc Controller) cursor_offset(doc_id nanoid.ID) u64 {
	return dc.docs[doc_id].cursor_offset()
}

pub fn (dc Controller) line_count(doc_id nanoid.ID) u64 {
	return dc.docs[doc_id].line_count()
}
