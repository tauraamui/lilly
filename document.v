module documents

import math
import os
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

pub fn (c Controller) get_char_at(doc_id int) ?string {
	pos := c.cursors[doc_id]
	current_line := c.docs[doc_id].data.get_line_at(y: pos.y) or { return none }
	for i, cc in current_line.runes_iterator() {
		if i == pos.x { return '${cc}' }
	}
	return none
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
	within_punct
	within_symbol
	unknown
}

enum CharType {
	alpha_num
	whitespace
	punctuation
	symbol
	unknown
}

fn CharType.resolve(c rune) CharType {
	return match true {
		is_punct(c) { .punctuation }
		is_symbol(c) { .symbol }
		utf8.is_space(c) { .whitespace }
		is_alpha_num(c) { .alpha_num }
		utf8.is_control(c) { .unknown }
		else { .unknown }
	}
}

fn (d Document) move_cursor_to_next_word_start(pos CursorPos) CursorPos {
	mut next_pos := pos
	for {
		if next_word_start_pos := scan_to_next_word_start(d.data, next_pos, pos.y) {
			return next_word_start_pos
		}
		next_pos = CursorPos{ y: next_pos.y + 1, x: 0 }
	}
	return pos
}

fn scan_to_next_word_start(data buffers.GapBuffer, pos CursorPos, source_y int) ?CursorPos {
	current_line := data.get_line_at(y: pos.y) or { return pos }

	if pos.y != source_y && pos.x == 0 {
		if current_line.len == 0 { return none }
		if CharType.resolve(current_line[pos.x]) == .alpha_num {
			return pos
		}
	}

	mut c_scanner := CharScanner{ last_index: pos.x, data: current_line.runes() }
	diff := c_scanner.next_diff() or { return none } {
		match diff.start_type {
			.alpha_num {
				match diff.next_type {
					.whitespace {
						post_whitespace_diff := c_scanner.next_diff() or { return none }
						return CursorPos{ y: pos.y, x: post_whitespace_diff.index }
					}
					else {}
				}
			}
			.whitespace {
				return CursorPos{ y: pos.y, x: diff.index }
			}
			else {}
		}
	}

	return pos
}


struct CharScanner {
	data       []rune
mut:
	last_index int
}

struct ScanResult {
	index      int
	cchar      rune
	start_type CharType
	next_type  CharType
}

fn (mut s CharScanner) next_diff() ?ScanResult {
	if s.data.len == 0 || s.last_index >= s.data.len { return none }
	start_type := CharType.resolve(s.data[s.last_index])
	for i := s.last_index; i < s.data.len; i++ {
		c := s.data[i]
		c_type := CharType.resolve(c)
		if c_type != start_type {
			s.last_index = i
			return ScanResult{ index: i, cchar: c, start_type: start_type, next_type: c_type }
		}
	}
	return none
}

pub fn is_alpha_num(c rune) bool {
	return utf8.is_letter(c) || utf8.is_number(c)
}

pub fn is_punct(c rune) bool {
	return utf8.is_rune_punct(c) || utf8.is_rune_global_punct(c)
}

pub fn is_symbol(c rune) bool {
	return !(utf8.is_space(c) || is_alpha_num(c) || is_punct(c) || utf8.is_control(c))
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
