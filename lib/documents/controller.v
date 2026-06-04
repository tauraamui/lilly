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
	dc.docs[doc_id].backspace()
}

pub fn (mut dc Controller2) move_cursor_right(doc_id int) {
	dc.docs[doc_id].move_cursor_right()
}

pub fn (mut dc Controller2) get_line_bytes(doc_id int, y u64) ?[]u8 {
	return dc.docs[doc_id].get_line_bytes(y)
}


