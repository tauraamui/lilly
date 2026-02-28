module documents

import math
import os
import arrays
import encoding.utf8
import lib.buffers
import petal

@[heap]
pub struct Controller {
mut:
	loaded_files map[string]int
	docs         map[int]Document
	cursors      map[int]CursorPos
	doc_id_count int
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
	c.cursors[id] = CursorPos{}
	return id
}

pub fn (mut c Controller) write_document(doc_id int) ! {
	// TODO(tauraamui): change error message emission to be just generic message emission
	// with type flags, so the location is the same, but formatting or visual rep is different
	target_file_path := c.docs[doc_id].file_path
	temp_file_path := os.join_path(os.temp_dir(), os.base(target_file_path))
	c.docs[doc_id].write_to(temp_file_path) or { return error('failed to write to temp location: ${temp_file_path}') }
	os.mv(temp_file_path, c.docs[doc_id].file_path) or { return error('failed to move temp location: ${temp_file_path} to dest: ${target_file_path}') }
}

pub fn (mut c Controller) prepare_for_insertion(doc_id int) ! {
	return c.docs[doc_id].prepare_for_insertion_at(c.cursors[doc_id])
}

pub fn (mut c Controller) prepare_for_insertion_at(doc_id int, pos CursorPos) ! {
	return c.docs[doc_id].prepare_for_insertion_at(pos)
}

pub fn (c Controller) cursor_pos(doc_id int) CursorPos {
	return c.cursors[doc_id]
}

pub fn (c Controller) visual_cursor_pos(doc_id int, tab_width int) CursorPos {
	return c.docs[doc_id].visual_cursor_pos(c.cursors[doc_id], tab_width)
}

pub fn (mut c Controller) move_cursor_left(doc_id int, mode petal.Mode) {
	pos := c.cursors[doc_id]
	c.cursors[doc_id] = c.docs[doc_id].move_cursor_left(pos, mode)
}

pub fn (mut c Controller) move_cursor_up(doc_id int, mode petal.Mode) {
	pos := c.cursors[doc_id]
	c.cursors[doc_id] = c.docs[doc_id].move_cursor_up(pos, mode)
}

pub fn (mut c Controller) move_cursor_down(doc_id int, mode petal.Mode) {
	pos := c.cursors[doc_id]
	c.cursors[doc_id] = c.docs[doc_id].move_cursor_down(pos, mode)
}

pub fn (mut c Controller) move_cursor_right(doc_id int, mode petal.Mode) {
	pos := c.cursors[doc_id]
	c.cursors[doc_id] = c.docs[doc_id].move_cursor_right(pos, mode)
}

pub fn (mut c Controller) move_cursor_to_next_word_start(doc_id int) {
	pos := c.cursors[doc_id]
	c.cursors[doc_id] = c.docs[doc_id].move_cursor_to_next_word_start(pos)
}

pub fn (mut c Controller) move_cursor_to_line_end(doc_id int, mode petal.Mode) {
	pos := c.cursors[doc_id]
	c.cursors[doc_id] = c.docs[doc_id].move_cursor_to_line_end(pos, mode)
}

pub fn (mut c Controller) insert_newline(doc_id int) {
	c.docs[doc_id].insert_char(`\n`)
	c.move_cursor_up(doc_id, .insert) // will need to have a 'cursor_up_and_start'
}

pub fn (mut c Controller) insert_char(doc_id int, data rune) {
	c.docs[doc_id].insert_char(data)
	c.move_cursor_right(doc_id, .insert)
}

pub fn (c Controller) get_line_at(doc_id int, y int) ?string {
	return c.docs[doc_id].data.get_line_at(y: y)
}

pub fn (c Controller) get_iterator(doc_id int) LineIterator {
	return c.docs[doc_id].iter()
}

pub fn (mut c Controller) free() {
	unsafe {
		c.docs.free()
		c.cursors.free()
	}
}

fn hash_id(id int) int {
	// constant is from Knuth's multiplicative hash
	hash := (id * 2654435761) % 1000000
	return math.abs(hash)
}

pub struct CursorPos {
pub:
	y int
	x int
}

@[heap]
pub struct Document {
mut:
	file_path string
	data buffers.GapBuffer
}

fn Document.new(file_path string) !Document {
	return Document{
		file_path: file_path
		data: buffers.GapBuffer.new(content: (os.read_file(file_path) or {
			return error('failed to read file ${file_path}: ${err}')
		}).runes())
		// data: buffers.GapBuffer.new(content: (iconv.read_file_encoding(file_path, "UTF-8") or { return error("failed to read file ${file_path}: ${err}") }).runes())
	}
}

fn (mut d Document) write_to(file_path string) ! {
	os.write_file(file_path, d.data.content().string())!
}

fn (mut d Document) prepare_for_insertion_at(pos CursorPos) ! {
	if offset := d.data.cursor_to_offset(x: pos.x, y: pos.y) {
		d.data.move_gap(offset)
		return
	}
	return error('unable to convert cursor pos to offset')
}

fn (d Document) move_cursor_left(pos CursorPos, mode petal.Mode) CursorPos {
	mut x := pos.x - 1
	return CursorPos{
		x: if x < 0 { 0 } else { x }
		y: pos.y
	}
}

fn (d Document) move_cursor_down(pos CursorPos, mode petal.Mode) CursorPos {
	// NOTE(tauraamui): for now just drop x to 0 each
	mut y := pos.y + 1
	d.data.get_line_at(y: y) or { return pos }
	return CursorPos{
		x: 0
		y: y
	}
}

fn (d Document) move_cursor_up(pos CursorPos, mode petal.Mode) CursorPos {
	// NOTE(tauraamui): for now just drop x to 0 each
	mut y := pos.y - 1
	d.data.get_line_at(y: y) or { return pos }
	return CursorPos{
		x: 0
		y: y
	}
}

fn (d Document) move_cursor_right(pos CursorPos, mode petal.Mode) CursorPos {
	current_line := d.data.get_line_at(y: pos.y) or { return pos }
	new_pos := CursorPos {
		x: pos.x + 1
		y: pos.y
	}

	return match mode {
		.normal {
			if pos.x + 1 >= current_line.runes().len { pos } else { new_pos }
		}
		.insert {
			if pos.x + 1 > current_line.runes().len { pos } else { new_pos }
		}
		else {
			new_pos
		}
	}
}

enum CursorSituation {
	within_word
	within_whitespace
}

fn (d Document) move_cursor_to_next_word_start(pos CursorPos) CursorPos {
	current_line := d.data.get_line_at(y: pos.y) or { return pos }
	current_line_data := current_line.runes()

	match resolve_cursor_situation(pos.x, current_line_data) {
		.within_word {
			whitespace_span_start := arrays.index_of_first(current_line_data, fn [pos] (idx int, c rune) bool { return idx >= pos.x && utf8.is_space(c) })
			whitespace_span_end   := arrays.index_of_first(current_line_data, fn [whitespace_span_start] (idx int, c rune) bool { return idx >= whitespace_span_start && !utf8.is_space(c) })
			return CursorPos{ y: pos.y, x: whitespace_span_end }
		}
		.within_whitespace {
			println("x: ${pos.x}. WITHIN WHITESPACE")
		}
	}

	return pos
}

fn resolve_cursor_situation(index int, data []rune) CursorSituation {
	return if utf8.is_space(data[index]) { .within_whitespace } else { .within_word }
}

fn (d Document) move_cursor_to_line_end(pos CursorPos, mode petal.Mode) CursorPos {
	current_line := d.data.get_line_at(y: pos.y) or { return pos }
	new_pos := CursorPos {
		x: pos.x + (current_line.runes().len - pos.x)
		y: pos.y
	}
	return new_pos
}

fn (d Document) visual_cursor_pos(pos CursorPos, tab_width int) CursorPos {
	tab_count := d.data.get_line_at(y: pos.y) or { return pos }[..pos.x].count('\t')
	return CursorPos{ x: (pos.x - tab_count) + (tab_count * tab_width), y: pos.y }
}

fn (mut d Document) insert_char(c rune) {
	d.data.insert_char(c)
}

pub fn (d Document) iter() LineIterator {
	return d.data.iter()
}

pub interface LineIterator {
mut:
	next() ?[]rune
}
