module documents

import io
import os
import lib.buffers

@[heap]
pub struct Controller2 {
mut:
	docs    map[int]buffers.TextBuffer = map[int]buffers.TextBuffer{}
	next_id int
}

pub fn Controller2.new() Controller2 {
	return Controller2{
		docs: map[int]buffers.TextBuffer{}
	}
}

pub fn (mut dc Controller2) open_document(path string) !int {
	mut file := os.open(path) or { return error('failed to open ${path}: ${err}') }
	defer {
		file.close()
	}
	return dc.load_document_from_reader(mut file)
}

pub fn (mut dc Controller2) load_document_from_reader(mut r io.Reader) !int {
	mut text_buf := buffers.TextBuffer.new()
	mut single_byte := []u8{len: 1}
	for {
		read := r.read(mut single_byte) or {
			if err is io.Eof{} {
				break
			}
			return error('read error: ${err}')
		}
		if read == 0 {
			continue
		}
		text_buf.insert(single_byte[0])
	}
	text_buf.move_cursor_to_start()
	doc_id := dc.next_id
	dc.next_id += 1
	dc.docs[doc_id] = text_buf
	return doc_id
}

pub fn (mut dc Controller2) insert(doc_id int, c u8) {
	dc.docs[doc_id].insert(c)
}

pub fn (mut dc Controller2) backspace(doc_id int) {
	for dc.last_codepoint_is_combiner(doc_id) {
		dc.docs[doc_id].backspace()
	}
	dc.docs[doc_id].backspace()
}

fn (dc Controller2) last_codepoint_is_combiner(doc_id int) bool {
	cursor_line, cursor_x := dc.docs[doc_id].cursor_line_and_x()
	if cursor_x == 0 {
		return false
	}
	line_bytes := dc.docs[doc_id].get_line_bytes(cursor_line) or { return false }
	if int(cursor_x) > line_bytes.len {
		return false
	}
	mut i := int(cursor_x) - 1
	for i > 0 && line_bytes[i] & 0xC0 == 0x80 {
		i -= 1
	}
	return is_combiner_at(line_bytes, i)
}

fn is_combiner_at(b []u8, i int) bool {
	if i >= b.len {
		return false
	}
	c0 := b[i]
	// 2-byte combining diacriticals U+0300..U+036F (CC 80..CD AF)
	if c0 == 0xCC || c0 == 0xCD {
		return true
	}
	// 3-byte ZWJ U+200D (E2 80 8D)
	if c0 == 0xE2 && i + 2 < b.len && b[i + 1] == 0x80 && b[i + 2] == 0x8D {
		return true
	}
	// 3-byte variation selectors VS1..VS16 U+FE00..U+FE0F (EF B8 80..8F)
	if c0 == 0xEF && i + 2 < b.len && b[i + 1] == 0xB8 && b[i + 2] >= 0x80 && b[i + 2] <= 0x8F {
		return true
	}
	return false
}

pub fn (mut dc Controller2) delete(doc_id int) {
	dc.docs[doc_id].delete()
}

pub fn (mut dc Controller2) move_cursor_left(doc_id int) {
	dc.docs[doc_id].move_cursor_left()
}

pub fn (mut dc Controller2) move_cursor_right(doc_id int) {
	dc.docs[doc_id].move_cursor_right()
}

pub fn (mut dc Controller2) move_cursor_up(doc_id int) {
	dc.docs[doc_id].move_cursor_up()
}

pub fn (mut dc Controller2) move_cursor_down(doc_id int) {
	dc.docs[doc_id].move_cursor_down()
}

pub fn (mut dc Controller2) get_line_bytes(doc_id int, y u64) ?[]u8 {
	return dc.docs[doc_id].get_line_bytes(y)
}

pub fn (dc Controller2) cursor_line_and_x(doc_id int) (u64, u64) {
	return dc.docs[doc_id].cursor_line_and_x()
}

pub fn (dc Controller2) line_count(doc_id int) u64 {
	return dc.docs[doc_id].line_count()
}


