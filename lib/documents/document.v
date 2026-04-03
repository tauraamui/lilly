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

import math
import os
import encoding.utf8
import lib.buffers
import lib.documents.cursor
import lib.files
import lib.petal

struct UndoEntry {
	cursor_before  cursor.Pos
	cursor_after   cursor.Pos
	content_before []rune
	content_after  []rune
}

struct UndoManager {
mut:
	undo_stack      []UndoEntry
	redo_stack      []UndoEntry
	pending_cursor  ?cursor.Pos
	pending_content []rune
	in_group        bool
}

fn (mut um UndoManager) begin_group(cur cursor.Pos, content []rune) {
	um.pending_cursor = cur
	um.pending_content = content
	um.in_group = true
}

fn (mut um UndoManager) commit_group(cur cursor.Pos, content []rune) {
	if !um.in_group {
		return
	}
	um.in_group = false
	pending_cur := um.pending_cursor or { return }
	if um.pending_content == content {
		return
	}
	um.undo_stack << UndoEntry{
		cursor_before:  pending_cur
		cursor_after:   cur
		content_before: um.pending_content
		content_after:  content
	}
	um.redo_stack.clear()
}

fn (mut um UndoManager) undo() ?UndoEntry {
	if um.undo_stack.len == 0 {
		return none
	}
	entry := um.undo_stack.pop()
	um.redo_stack << entry
	return entry
}

fn (mut um UndoManager) redo() ?UndoEntry {
	if um.redo_stack.len == 0 {
		return none
	}
	entry := um.redo_stack.pop()
	um.undo_stack << entry
	return entry
}

@[heap]
pub struct Controller {
mut:
	loaded_files  map[string]int
	docs          map[int]Document
	undo_managers map[int]UndoManager
	doc_id_count  int
}

pub fn Controller.new() Controller {
	return Controller{}
}

pub fn (mut c Controller) open_document(file_path string) !int {
	if existing_id := c.loaded_files[file_path] {
		return existing_id
	}
	defer { c.doc_id_count += 1 }
	id := hash_id(c.doc_id_count)
	c.loaded_files[file_path] = id
	c.docs[id] = Document.new(file_path)!
	c.undo_managers[id] = UndoManager{}
	return id
}

pub fn (mut c Controller) write_document(doc_id int) ! {
	// TODO(tauraamui): change error message emission to be just generic message emission
	// with type flags, so the location is the same, but formatting or visual rep is different
	target_file_path := c.docs[doc_id].file_path
	temp_file_path := os.join_path(os.temp_dir(), os.base(target_file_path))
	c.docs[doc_id].write_to(temp_file_path) or {
		return error('failed to write to temp location: ${temp_file_path}')
	}
	os.mv(temp_file_path, c.docs[doc_id].file_path) or {
		return error('failed to move temp location: ${temp_file_path} to dest: ${target_file_path}')
	}
}

pub fn (mut c Controller) begin_undo_group(doc_id int, pos cursor.Pos) {
	c.undo_managers[doc_id].begin_group(pos, c.docs[doc_id].data.content())
}

pub fn (mut c Controller) commit_undo_group(doc_id int, pos cursor.Pos) {
	c.undo_managers[doc_id].commit_group(pos, c.docs[doc_id].data.content())
}

pub fn (mut c Controller) undo(doc_id int) ?cursor.Pos {
	if entry := c.undo_managers[doc_id].undo() {
		c.docs[doc_id].data.set_content(entry.content_before)
		return entry.cursor_before
	}
	return none
}

pub fn (mut c Controller) redo(doc_id int) ?cursor.Pos {
	if entry := c.undo_managers[doc_id].redo() {
		c.docs[doc_id].data.set_content(entry.content_after)
		return entry.cursor_after
	}
	return none
}

pub fn (mut c Controller) prepare_for_insertion_at(doc_id int, pos cursor.Pos) ! {
	return c.docs[doc_id].prepare_for_insertion_at(pos)
}

pub fn (c Controller) visual_pos_for(doc_id int, pos cursor.Pos, tab_width int) cursor.Pos {
	return c.docs[doc_id].visual_cursor_pos(pos, tab_width)
}

pub fn (c Controller) move_cursor_left(doc_id int, pos cursor.Pos, mode petal.Mode) cursor.Pos {
	return c.docs[doc_id].move_cursor_left(pos, mode)
}

pub fn (c Controller) move_cursor_up(doc_id int, pos cursor.Pos, mode petal.Mode) cursor.Pos {
	return c.docs[doc_id].move_cursor_up(pos, mode)
}

pub fn (c Controller) move_cursor_down(doc_id int, pos cursor.Pos, mode petal.Mode) cursor.Pos {
	return c.docs[doc_id].move_cursor_down(pos, mode)
}

pub fn (c Controller) move_cursor_up_by(doc_id int, pos cursor.Pos, count int, mode petal.Mode) cursor.Pos {
	mut pending_pos := pos
	for _ in 0 .. count {
		new_pos := c.docs[doc_id].move_cursor_up(pending_pos, mode)
		if new_pos == pending_pos {
			break
		}
		pending_pos = new_pos
	}
	return pending_pos
}

pub fn (c Controller) move_cursor_down_by(doc_id int, pos cursor.Pos, count int, mode petal.Mode) cursor.Pos {
	mut pending_pos := pos
	for _ in 0 .. count {
		new_pos := c.docs[doc_id].move_cursor_down(pending_pos, mode)
		if new_pos == pending_pos {
			break
		}
		pending_pos = new_pos
	}
	return pending_pos
}

pub fn (c Controller) move_cursor_right(doc_id int, pos cursor.Pos, mode petal.Mode) cursor.Pos {
	return c.docs[doc_id].move_cursor_right(pos, mode)
}

pub fn (c Controller) move_cursor_to_next_word_start(doc_id int, pos cursor.Pos) cursor.Pos {
	return c.docs[doc_id].move_cursor_to_next_word_start(pos)
}

pub fn (c Controller) move_cursor_to_previous_word_start(doc_id int, pos cursor.Pos) cursor.Pos {
	return c.docs[doc_id].move_cursor_to_previous_word_start(pos)
}

pub fn (c Controller) move_cursor_to_next_word_end(doc_id int, pos cursor.Pos) cursor.Pos {
	return c.docs[doc_id].move_cursor_to_next_word_end(pos)
}

pub fn (c Controller) move_cursor_to_previous_word_end(doc_id int, pos cursor.Pos) cursor.Pos {
	return c.docs[doc_id].move_cursor_to_previous_word_end(pos)
}

pub fn (c Controller) move_cursor_to_next_big_word_start(doc_id int, pos cursor.Pos) cursor.Pos {
	return c.docs[doc_id].move_cursor_to_next_big_word_start(pos)
}

pub fn (c Controller) move_cursor_to_line_end(doc_id int, pos cursor.Pos, mode petal.Mode) cursor.Pos {
	return c.docs[doc_id].move_cursor_to_line_end(pos, mode)
}

pub fn (c Controller) move_cursor_to_line_start(doc_id int, pos cursor.Pos) cursor.Pos {
	return c.docs[doc_id].move_cursor_to_line_start(pos)
}

pub fn (c Controller) move_cursor_to_next_blank_line(doc_id int, pos cursor.Pos) cursor.Pos {
	return c.docs[doc_id].move_cursor_to_next_blank_line(pos)
}

pub fn (c Controller) move_cursor_to_previous_blank_line(doc_id int, pos cursor.Pos) cursor.Pos {
	return c.docs[doc_id].move_cursor_to_previous_blank_line(pos)
}

pub fn (mut c Controller) insert_newline(doc_id int, pos cursor.Pos) cursor.Pos {
	c.docs[doc_id].insert_char(`\n`)
	return c.docs[doc_id].move_cursor_down(pos, .insert) // will need to have a 'cursor_up_and_start'
}

pub fn (mut c Controller) insert_char(doc_id int, pos cursor.Pos, data rune) cursor.Pos {
	c.docs[doc_id].insert_char(data)
	return c.docs[doc_id].move_cursor_right(pos, .insert)
}

pub fn (mut c Controller) clear_line(doc_id int, pos cursor.Pos) cursor.Pos {
	return c.docs[doc_id].clear_line(pos)
}

pub fn (mut c Controller) delete_line(doc_id int, pos cursor.Pos) cursor.Pos {
	return c.docs[doc_id].delete_line(pos)
}

pub fn (mut c Controller) delete_range(doc_id int, range cursor.Range) cursor.Pos {
	return c.docs[doc_id].delete_range(range)
}

pub fn (mut c Controller) delete_visual_range(doc_id int, range cursor.Range) cursor.Pos {
	return c.docs[doc_id].delete_visual_range(range)
}

pub fn (c Controller) leading_whitespace_on_current_line(doc_id int, pos cursor.Pos) []rune {
	current_line := c.docs[doc_id].data.get_line_at(y: pos.y) or { return [] }
	if current_line == '' {
		return []
	}
	mut first_non_whitespace_index := 0
	for i, cr in current_line.runes_iterator() {
		if CharType.resolve(cr) != .whitespace {
			first_non_whitespace_index = i
			break
		}
	}
	if first_non_whitespace_index == 0 {
		return []
	}
	return current_line.runes()[..first_non_whitespace_index]
}

pub fn (mut c Controller) backspace(doc_id int, pos cursor.Pos) ?cursor.Pos {
	if pos.x == 0 && pos.y == 0 {
		return pos
	}

	new_pos := if pos.x > 0 {
		cursor.Pos.new(pos.x - 1, pos.y)
	} else {
		prev_line := c.docs[doc_id].data.get_line_at(y: pos.y - 1) or { return none }
		cursor.Pos.new(prev_line.runes().len, pos.y - 1)
	}

	c.prepare_for_insertion_at(doc_id, pos) or { return none }
	c.docs[doc_id].delete_before()
	return new_pos
}

pub fn (mut c Controller) delete_char_at(doc_id int, pos cursor.Pos) {
	c.delete(doc_id, pos)
}

pub fn (mut c Controller) delete(doc_id int, pos cursor.Pos) {
	current_line := c.docs[doc_id].data.get_line_at(y: pos.y) or { return }
	line_len := current_line.runes().len

	if pos.x >= line_len {
		// at end of line, only delte if there's a next line to join
		c.docs[doc_id].data.get_line_at(y: pos.y + 1) or { return }
	}

	c.prepare_for_insertion_at(doc_id, pos) or { return }
	c.docs[doc_id].delete_after()
	// cursor does not move
}

pub fn (c Controller) get_line_at(doc_id int, y int) ?string {
	return c.docs[doc_id].data.get_line_at(y: y)
}

pub fn (c Controller) get_char_at(doc_id int, pos cursor.Pos) ?string {
	current_line := c.docs[doc_id].data.get_line_at(y: pos.y) or { return none }
	for i, cc in current_line.runes_iterator() {
		if i == pos.x {
			return '${cc}'
		}
	}
	return none
}

pub fn (c Controller) line_count(doc_id int) int {
	return c.docs[doc_id].line_count()
}

pub fn (c Controller) get_iterator(doc_id int) LineIterator {
	return c.docs[doc_id].iter()
}

pub fn (mut c Controller) free() {
	unsafe {
		c.docs.free()
	}
}

fn hash_id(id int) int {
	// constant is from Knuth's multiplicative hash
	hash := (id * 2654435761) % 1000000
	return math.abs(hash)
}

@[heap]
struct Document {
mut:
	file_path string
	data      buffers.GapBuffer
}

fn Document.new(file_path string) !Document {
	mut data := buffers.GapBuffer{}

	if !os.is_readable(file_path) {
		return error('${file_path} is not readable')
	}

	if files.is_binary(file_path) {
		return error('${file_path} is a binary file')
	}

	if !os.exists(file_path) {
		data = buffers.GapBuffer.new(
			content: ''.runes()
		)
	} else {
		data = buffers.GapBuffer.new(
			content: (os.read_file(file_path) or {
				return error('failed to read file ${file_path}: ${err}')
			}).runes()
		)
	}

	return Document{
		file_path: file_path
		data:      data
		// data: buffers.GapBuffer.new(content: (iconv.read_file_encoding(file_path, "UTF-8") or { return error("failed to read file ${file_path}: ${err}") }).runes())
	}
}

fn (mut d Document) write_to(file_path string) ! {
	if !os.exists(file_path) {
		os.create(file_path)!
	}
	os.write_file(file_path, d.data.content().string())!
}

fn (mut d Document) prepare_for_insertion_at(pos cursor.Pos) ! {
	if offset := d.data.cursor_to_offset(x: pos.x, y: pos.y) {
		d.data.move_gap(offset)
		return
	}
	return error('unable to convert cursor pos to offset')
}

fn (d Document) move_cursor_left(pos cursor.Pos, mode petal.Mode) cursor.Pos {
	// NOTE(tauraamui): should continue to clear/reset largest x field data to "re-cap"
	// to whatever the cursors new x pos becomes on move left
	return cursor.Pos.new(if pos.x - 1 < 0 { 0 } else { pos.x - 1 }, pos.y)
}

fn (d Document) move_cursor_down(pos cursor.Pos, mode petal.Mode) cursor.Pos {
	// TODO(tauraamui): use the line content to infer if largest x so far or line len should be returned x
	y := pos.y + 1
	if line := d.data.get_line_at(y: y) {
		line_data := line.runes()
		x := if pos.largest_x >= line_data.len { line_data.len - 1 } else { pos.largest_x }
		return pos.x(x).y(y)
	}
	return pos
}

fn (d Document) move_cursor_up(pos cursor.Pos, mode petal.Mode) cursor.Pos {
	// TODO(tauraamui): use the line content to infer if largest x so far or line len should be returned x
	y := pos.y - 1
	if line := d.data.get_line_at(y: y) {
		line_data := line.runes()
		x := if pos.largest_x >= line_data.len { line_data.len - 1 } else { pos.largest_x }
		return pos.x(x).y(y)
	}
	return pos
}

fn (d Document) move_cursor_right(pos cursor.Pos, mode petal.Mode) cursor.Pos {
	current_line := d.data.get_line_at(y: pos.y) or { return pos }
	x := pos.x + 1

	return match mode {
		.normal {
			if x >= current_line.runes().len {
				pos
			} else {
				pos.x(x)
			}
		}
		.insert {
			if x > current_line.runes().len {
				pos
			} else {
				pos.x(x)
			}
		}
		else {
			if x >= current_line.runes().len {
				pos
			} else {
				pos.x(x)
			}
		}
	}
}

fn (d Document) move_cursor_to_next_word_start(pos cursor.Pos) cursor.Pos {
	mut next_pos := pos
	for {
		if next_word_start_pos := scan_to_next_word_start(d.data, next_pos, pos.y) {
			return next_word_start_pos
		}
		next_y := next_pos.y + 1
		_ = d.data.get_line_at(y: next_y) or { return pos }
		next_pos = next_pos.x(0).y(next_y)
	}
	return pos
}

fn (d Document) move_cursor_to_previous_word_start(pos cursor.Pos) cursor.Pos {
	// NOTE(tauraamui): should continue to clear/reset largest x field data to "re-cap"
	// to whatever the cursors new x pos becomes on move left

	mut next_pos := pos
	for {
		if prev_word_start_pos := scan_to_previous_word_start(d.data, next_pos, pos.y) {
			return prev_word_start_pos
		}
		prev_y := next_pos.y - 1

		if prev_y < 0 {
			return pos
		}
		prev_line := d.data.get_line_at(y: prev_y) or { return pos }
		line_len := prev_line.runes().len
		if line_len == 0 {
			next_pos = cursor.Pos.new(0, prev_y)
		} else {
			next_pos = cursor.Pos.new(line_len - 1, prev_y)
		}
	}
	return pos
}

fn (d Document) move_cursor_to_next_word_end(pos cursor.Pos) cursor.Pos {
	mut next_pos := pos
	for {
		if next_word_end_pos := scan_to_next_word_end(d.data, next_pos, pos.y) {
			return next_word_end_pos
		}
		next_y := next_pos.y + 1
		_ = d.data.get_line_at(y: next_y) or { return pos }
		next_pos = next_pos.x(0).y(next_y)
	}
	return pos
}

fn (d Document) move_cursor_to_previous_word_end(pos cursor.Pos) cursor.Pos {
	mut next_pos := pos
	for {
		if prev_word_end_pos := scan_to_previous_word_end(d.data, next_pos, pos.y) {
			return prev_word_end_pos
		}
		prev_y := next_pos.y - 1
		if prev_y < 0 {
			return pos
		}
		prev_line := d.data.get_line_at(y: prev_y) or { return pos }
		line_len := prev_line.runes().len
		if line_len == 0 {
			next_pos = cursor.Pos.new(0, prev_y)
		} else {
			next_pos = cursor.Pos.new(line_len - 1, prev_y)
		}
	}
	return pos
}

fn (d Document) move_cursor_to_next_big_word_start(pos cursor.Pos) cursor.Pos {
	mut next_pos := pos
	for {
		if next_word_start_pos := scan_to_next_big_word_start(d.data, next_pos, pos.y) {
			return next_word_start_pos
		}
		next_y := next_pos.y + 1
		_ = d.data.get_line_at(y: next_y) or { return pos }
		next_pos = next_pos.x(0).y(next_y)
	}
	return pos
}

fn (d Document) move_cursor_to_line_end(pos cursor.Pos, mode petal.Mode) cursor.Pos {
	current_line := d.data.get_line_at(y: pos.y) or { return pos }
	return cursor.Pos.new(pos.x +
		(current_line.runes().len - pos.x - if mode == .normal { 1 } else { 0 }), pos.y)
}

fn (d Document) move_cursor_to_line_start(pos cursor.Pos) cursor.Pos {
	_ := d.data.get_line_at(y: pos.y) or { return pos }
	return cursor.Pos.new(0, pos.y)
}

fn (d Document) move_cursor_to_next_blank_line(pos cursor.Pos) cursor.Pos {
	mut last_y := pos.y
	for i, line in d.data.iter() {
		last_y = i
		if i > pos.y {
			if line.len == 0 {
				return pos.x(0).y(i)
			}
		}
	}
	if last_y > pos.y {
		return pos.x(0).y(last_y)
	}
	return pos
}

fn (d Document) move_cursor_to_previous_blank_line(pos cursor.Pos) cursor.Pos {
	mut last_blank := -1
	for i, line in d.data.iter() {
		if i >= pos.y {
			break
		}
		if line.len == 0 {
			last_blank = i
		}
	}
	if last_blank >= 0 {
		return pos.x(0).y(last_blank)
	}
	if pos.y > 0 {
		return pos.x(0).y(0)
	}
	return pos
}

fn (d Document) visual_cursor_pos(pos cursor.Pos, tab_width int) cursor.Pos {
	line := d.data.get_line_at(y: pos.y) or { return pos }
	runes := line.runes()
	prefix := runes[..pos.x]
	mut visual_x := 0
	for r in prefix {
		if r == `\t` {
			visual_x += tab_width
		} else {
			visual_x += utf8_str_visible_length(r.str())
		}
	}
	return pos.x(visual_x)
}

fn (mut d Document) insert_char(c rune) {
	d.data.insert_char(c)
}

fn (mut d Document) clear_line(pos cursor.Pos) cursor.Pos {
	line_y := pos.y
	line := d.data.get_line_at(y: line_y) or { return pos.x(0).y(line_y) }
	line_len := line.runes().len
	if line_len == 0 {
		return pos.x(0).y(line_y)
	}
	d.prepare_for_insertion_at(pos.x(0).y(line_y)) or { return pos.x(0).y(line_y) }
	d.data.delete_after_n(line_len)

	return pos.x(0).y(line_y)
}

fn (mut d Document) delete_line(pos cursor.Pos) cursor.Pos {
	line_y := pos.y
	line := d.data.get_line_at(y: line_y) or { return pos.x(0).y(line_y) }
	line_len := line.runes().len
	has_next_line := d.data.get_line_at(y: line_y + 1) != none
	has_prev_line := line_y > 0

	if has_next_line {
		// delete line content + trailing newline
		d.prepare_for_insertion_at(cursor.Pos.new(0, line_y)) or { return pos.x(0).y(line_y) }
		d.data.delete_after_n(line_len + 1)
		return cursor.Pos.new(0, line_y)
	} else if has_prev_line {
		// last line: delete preceding newline + line content
		prev_line := d.data.get_line_at(y: line_y - 1) or { return pos.x(0).y(line_y) }
		prev_line_len := prev_line.runes().len
		d.prepare_for_insertion_at(cursor.Pos.new(prev_line_len, line_y - 1)) or {
			return pos.x(0).y(line_y)
		}
		d.data.delete_after_n(1 + line_len)
		return cursor.Pos.new(0, line_y - 1)
	} else {
		// only line in document: just clear it
		if line_len == 0 {
			return pos.x(0).y(line_y)
		}
		d.prepare_for_insertion_at(cursor.Pos.new(0, line_y)) or { return pos.x(0).y(line_y) }
		d.data.delete_after_n(line_len)
		return cursor.Pos.new(0, line_y)
	}
}

fn (mut d Document) delete_range(range cursor.Range) cursor.Pos {
	start_y := if range.start.y < range.end.y { range.start.y } else { range.end.y }
	end_y := if range.start.y > range.end.y { range.start.y } else { range.end.y }

	// Calculate total runes to delete: all line contents + newlines between them
	mut total_len := 0
	for y in start_y .. end_y + 1 {
		line := d.data.get_line_at(y: y) or { continue }
		total_len += line.runes().len
		if y < end_y {
			total_len += 1 // newline separator
		}
	}

	has_next_line := d.data.get_line_at(y: end_y + 1) != none
	has_prev_line := start_y > 0

	if has_next_line {
		// Delete range content + trailing newline
		d.prepare_for_insertion_at(cursor.Pos.new(0, start_y)) or {
			return cursor.Pos.new(0, start_y)
		}
		d.data.delete_after_n(total_len + 1)
		return cursor.Pos.new(0, start_y)
	} else if has_prev_line {
		// Last lines: delete preceding newline + range content
		prev_line := d.data.get_line_at(y: start_y - 1) or { return cursor.Pos.new(0, start_y) }
		prev_line_len := prev_line.runes().len
		d.prepare_for_insertion_at(cursor.Pos.new(prev_line_len, start_y - 1)) or {
			return cursor.Pos.new(0, start_y)
		}
		d.data.delete_after_n(1 + total_len)
		return cursor.Pos.new(0, start_y - 1)
	} else {
		// Only lines in document: just clear them
		if total_len == 0 {
			return cursor.Pos.new(0, 0)
		}
		d.prepare_for_insertion_at(cursor.Pos.new(0, 0)) or { return cursor.Pos.new(0, 0) }
		d.data.delete_after_n(total_len)
		return cursor.Pos.new(0, 0)
	}
}

fn (mut d Document) delete_visual_range(range cursor.Range) cursor.Pos {
	// Normalize so start is before end
	start := if range.start.y < range.end.y
		|| (range.start.y == range.end.y && range.start.x <= range.end.x) {
		range.start
	} else {
		range.end
	}
	end := if range.start.y < range.end.y
		|| (range.start.y == range.end.y && range.start.x <= range.end.x) {
		range.end
	} else {
		range.start
	}

	if start.y == end.y {
		// Single line: delete from start.x to end.x (inclusive)
		line := d.data.get_line_at(y: start.y) or { return start }
		line_len := line.runes().len
		del_start := if start.x < line_len { start.x } else { line_len }
		del_end := if end.x < line_len { end.x } else { line_len - 1 }
		count := del_end - del_start + 1
		if count <= 0 {
			return start
		}
		d.prepare_for_insertion_at(cursor.Pos.new(del_start, start.y)) or { return start }
		d.data.delete_after_n(count)
		return cursor.Pos.new(del_start, start.y)
	}

	// Multi-line: delete from start pos to end pos (inclusive)
	// Calculate total runes: rest of start line + newlines + middle lines + start of end line
	mut total := 0

	// Rest of start line from start.x
	start_line := d.data.get_line_at(y: start.y) or { return start }
	start_line_len := start_line.runes().len
	total += start_line_len - start.x
	total += 1 // newline after start line

	// Full middle lines
	for y in start.y + 1 .. end.y {
		mid_line := d.data.get_line_at(y: y) or { continue }
		total += mid_line.runes().len + 1 // line content + newline
	}

	// Start of end line up to and including end.x
	end_line := d.data.get_line_at(y: end.y) or { return start }
	end_x := if end.x < end_line.runes().len { end.x } else { end_line.runes().len - 1 }
	total += end_x + 1

	if total <= 0 {
		return start
	}
	d.prepare_for_insertion_at(cursor.Pos.new(start.x, start.y)) or { return start }
	d.data.delete_after_n(total)
	return cursor.Pos.new(start.x, start.y)
}

fn (mut d Document) delete_before() {
	d.data.delete_before()
}

fn (mut d Document) delete_after() {
	d.data.delete_after()
}

pub fn (d Document) iter() LineIterator {
	return d.data.iter()
}

fn (d Document) line_count() int {
	mut count := 0
	mut iter := d.data.iter()
	for {
		_ = iter.next() or { break }
		count += 1
	}
	return count
}

enum CursorSituation {
	within_word
	within_whitespace
	within_other
}

pub enum CharType {
	alpha_num
	whitespace
	other
}

pub fn CharType.resolve(c rune) CharType {
	return match true {
		utf8.is_space(c) { .whitespace }
		is_alpha_num(c) { .alpha_num }
		else { .other }
	}
}

fn scan_to_next_word_start(data buffers.GapBuffer, pos cursor.Pos, source_y int) ?cursor.Pos {
	current_line := data.get_line_at(y: pos.y) or { return pos }

	if pos.y != source_y && pos.x == 0 {
		if current_line.len == 0 {
			return pos
		}
		if CharType.resolve(current_line[pos.x]) != .whitespace {
			return pos
		}
	}

	mut c_scanner := CharScanner{
		last_index: pos.x
		data:       current_line.runes()
	}
	diff := c_scanner.next_diff() or { return none }

	if diff.next_type == .whitespace {
		post_whitespace_diff := c_scanner.next_diff() or { return none }
		return cursor.Pos.new(post_whitespace_diff.index, pos.y)
	}
	if diff.start_type == .whitespace {
		return cursor.Pos.new(diff.index, pos.y)
	}
	return cursor.Pos.new(diff.index, pos.y)
}

fn find_prev_token_start(mut c_scanner CharScanner, y int) ?cursor.Pos {
	diff := c_scanner.prev_diff() or { return cursor.Pos.new(0, y) }
	if pre := diff.pre_diff {
		return cursor.Pos.new(pre.index, y)
	}
	return cursor.Pos.new(diff.index + 1, y)
}

// NOTE(tauraamui): this method always continue to should destruct the cursor instance on mutation to obliterate
// the stored largest x state
fn scan_to_previous_word_start(data buffers.GapBuffer, pos cursor.Pos, source_y int) ?cursor.Pos {
	current_line := data.get_line_at(y: pos.y) or { return pos }

	if pos.y != source_y {
		if current_line.len == 0 {
			return pos
		}
		if pos.x == 0 {
			if CharType.resolve(current_line[pos.x]) != .whitespace {
				return pos
			}
		} else {
			c_type := CharType.resolve(current_line[pos.x])
			if c_type != .whitespace {
				mut word_start := pos.x
				for i := pos.x - 1; i >= 0; i-- {
					ci_type := CharType.resolve(current_line[i])
					if ci_type != c_type {
						break
					}
					word_start = i
				}
				return cursor.Pos.new(word_start, pos.y)
			}
		}
	}

	mut c_scanner := CharScanner{
		last_index: pos.x
		data:       current_line.runes()
	}
	diff := c_scanner.prev_diff() or { return none }

	if diff.start_type == .alpha_num || diff.start_type == .other {
		if pre := diff.pre_diff {
			return cursor.Pos.new(pre.index, pos.y)
		}
		if diff.next_type == .whitespace {
			c_scanner.prev_diff() or { return none }
			return find_prev_token_start(mut c_scanner, pos.y)
		}
		// crossed to other non-whitespace class — find start of that word
		return find_prev_token_start(mut c_scanner, pos.y)
	}

	if diff.start_type == .whitespace {
		return find_prev_token_start(mut c_scanner, pos.y)
	}

	return pos
}

fn scan_to_next_word_end(data buffers.GapBuffer, pos cursor.Pos, source_y int) ?cursor.Pos {
	current_line := data.get_line_at(y: pos.y) or { return pos }
	runes := current_line.runes()

	if pos.y != source_y && pos.x == 0 {
		if runes.len == 0 {
			return pos
		}
	}

	start := if pos.y == source_y { pos.x + 1 } else { pos.x }
	if start >= runes.len {
		return none
	}

	mut x := start
	// skip whitespace
	for x < runes.len && CharType.resolve(runes[x]) == .whitespace {
		x++
	}
	if x >= runes.len {
		return none
	}

	// find end of word class
	word_class := CharType.resolve(runes[x])
	for x + 1 < runes.len && CharType.resolve(runes[x + 1]) == word_class {
		x++
	}

	return cursor.Pos.new(x, pos.y)
}

fn scan_to_next_big_word_start(data buffers.GapBuffer, pos cursor.Pos, source_y int) ?cursor.Pos {
	current_line := data.get_line_at(y: pos.y) or { return pos }
	runes := current_line.runes()

	if pos.y != source_y && pos.x == 0 {
		if runes.len == 0 {
			return pos
		}
		if !utf8.is_space(runes[pos.x]) {
			return pos
		}
	}

	mut x := pos.x

	// skip non-whitespace
	for x < runes.len && !utf8.is_space(runes[x]) {
		x++
	}
	// skip whitespace
	for x < runes.len && utf8.is_space(runes[x]) {
		x++
	}

	if x >= runes.len {
		return none
	}
	return cursor.Pos.new(x, pos.y)
}

fn scan_to_previous_word_end(data buffers.GapBuffer, pos cursor.Pos, source_y int) ?cursor.Pos {
	current_line := data.get_line_at(y: pos.y) or { return pos }
	runes := current_line.runes()

	if pos.y != source_y {
		if runes.len == 0 {
			return pos
		}
		// cross-line: find last non-whitespace char on this line
		mut x := runes.len - 1
		for x >= 0 && CharType.resolve(runes[x]) == .whitespace {
			x--
		}
		if x < 0 {
			return none
		}
		return cursor.Pos.new(x, pos.y)
	}

	if pos.x <= 0 {
		return none
	}

	mut x := pos.x - 1
	curr_class := CharType.resolve(runes[x])

	if curr_class == .whitespace {
		// skip whitespace backward
		for x >= 0 && CharType.resolve(runes[x]) == .whitespace {
			x--
		}
		if x < 0 {
			return none
		}
		return cursor.Pos.new(x, pos.y)
	}

	orig_class := CharType.resolve(runes[pos.x])
	if curr_class != orig_class {
		// stepped into different class — x is a word end
		return cursor.Pos.new(x, pos.y)
	}

	// same class — skip backward past current word
	for x >= 0 && CharType.resolve(runes[x]) == curr_class {
		x--
	}
	if x < 0 {
		return none
	}

	// skip whitespace if present
	if CharType.resolve(runes[x]) == .whitespace {
		for x >= 0 && CharType.resolve(runes[x]) == .whitespace {
			x--
		}
		if x < 0 {
			return none
		}
	}

	return cursor.Pos.new(x, pos.y)
}

struct CharScanner {
	data []rune
mut:
	last_index int
}

struct ScanResult {
	index      int
	cchar      rune
	cchar_str  string
	pre_diff   ?PreDiffChar
	start_type CharType
	next_type  CharType
}

struct PreDiffChar {
	index     int
	cchar     rune
	cchar_str string
	c_type    CharType
}

fn (mut s CharScanner) prev_diff() ?ScanResult {
	if s.data.len == 0 || s.last_index <= 0 {
		return none
	}
	start_type := CharType.resolve(s.data[s.last_index])
	for i := s.last_index; i >= 0; i-- {
		c := s.data[i]
		c_type := CharType.resolve(c)
		pre_diff_char := ?PreDiffChar(if i + 1 < s.last_index {
			PreDiffChar{
				index:     i + 1
				cchar:     s.data[i + 1]
				cchar_str: s.data[i + 1].str()
				c_type:    CharType.resolve(s.data[i + 1])
			}
		} else {
			none
		})

		if c_type != start_type {
			s.last_index = i
			return ScanResult{
				index:      i
				cchar:      c
				cchar_str:  c.str()
				pre_diff:   pre_diff_char
				start_type: start_type
				next_type:  c_type
			}
		}
	}
	return none
}

fn (mut s CharScanner) next_diff() ?ScanResult {
	if s.data.len == 0 || s.last_index >= s.data.len {
		return none
	}
	start_type := CharType.resolve(s.data[s.last_index])
	for i := s.last_index; i < s.data.len; i++ {
		c := s.data[i]
		c_type := CharType.resolve(c)
		if c_type != start_type {
			s.last_index = i
			return ScanResult{
				index:      i
				cchar:      c
				cchar_str:  c.str()
				start_type: start_type
				next_type:  c_type
			}
		}
	}
	return none
}

pub fn is_alpha_num(c rune) bool {
	return utf8.is_letter(c) || utf8.is_number(c) || c == '_'.runes()[0]
}

pub interface LineIterator {
mut:
	next() ?[]rune
}
