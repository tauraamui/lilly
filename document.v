module documents

import math
import os
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

pub fn (mut c Controller) prepare_for_insertion(doc_id int) ! {
	return c.docs[doc_id].prepare_for_insertion_at(c.cursors[doc_id])
}

pub fn (mut c Controller) prepare_for_insertion_at(doc_id int, pos CursorPos) ! {
	return c.docs[doc_id].prepare_for_insertion_at(pos)
}

pub fn (c Controller) cursor_pos(doc_id int) CursorPos {
	return c.cursors[doc_id]
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

pub fn (mut c Controller) insert_newline(doc_id int) {
	c.docs[doc_id].insert_char(`\n`)
	c.move_cursor_up(doc_id, .insert) // will need to have a 'cursor_up_and_start'
}

pub fn (mut c Controller) insert_char(doc_id int, data rune) {
	c.docs[doc_id].insert_char(data)
	c.move_cursor_right(doc_id, .insert)
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
	data buffers.GapBuffer
}

fn Document.new(file_path string) !Document {
	return Document{
		data: buffers.GapBuffer.new(content: (os.read_file(file_path) or {
			return error('failed to read file ${file_path}: ${err}')
		}).runes())
		// data: buffers.GapBuffer.new(content: (iconv.read_file_encoding(file_path, "UTF-8") or { return error("failed to read file ${file_path}: ${err}") }).runes())
	}
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

fn (d Document) move_cursor_up(pos CursorPos, mode petal.Mode) CursorPos {
	// NOTE(tauraamui): for now just drop x to 0 each
	mut y := pos.y + 1
	d.data.get_line_at(y: y) or { return pos }
	return CursorPos{
		x: 0
		y: y
	}
}

fn (d Document) move_cursor_down(pos CursorPos, mode petal.Mode) CursorPos {
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
	match mode {
		.normal {
			if pos.x + 1 >= current_line.runes().len { return pos }
		}
		.insert {
			if pos.x + 1 > current_line.runes().len { return pos }
		}
		else {
		}
	}
	return CursorPos{
		x: pos.x + 1
		y: pos.y
	}
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
