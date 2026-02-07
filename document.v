module documents

import math
import encoding.iconv
import lib.buffers

@[heap]
pub struct Controller {
mut:
	loaded_files map[string]int
	docs         map[int]Document
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
	return id
}

/*
pub fn (mut c Controller) distance_to_move(start_pos CursorPos, end_pos CursorPos) ?int {
	start_offset := d.data.cursor_to_offset(start_pos) or { return none }
	end_offset := d.data.cursor_to_offset(end_pos) or { return none }
}
*/

pub fn (mut c Controller) prepare_for_insertion_at(doc_id int, pos CursorPos) {
	c.docs[doc_id].prepare_for_insertion_at(pos)
}

pub fn (mut c Controller) insert_char(doc_id int, data rune) {
	c.docs[doc_id].insert_char(data)
}

pub fn (c Controller) get_iterator(doc_id int) LineIterator {
	return c.docs[doc_id].iter()
}

pub fn (mut c Controller) free() {
	unsafe { c.docs.free( )}
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
		data: buffers.GapBuffer.new(content: (iconv.read_file_encoding(file_path, "UTF-8") or { return error("failed to read file ${file_path}: ${err}") }).runes())
	}
}

pub fn (mut d Document) prepare_for_insertion_at(pos CursorPos) {
	if offset := d.data.cursor_to_offset(x: pos.x, y: pos.y) {
		d.data.move_gap(offset)
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

