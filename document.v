module documents

import encoding.iconv
import lib.buffers

@[heap]
pub struct Controller {
mut:
	docs map[int]Document
}

pub fn Controller.new() Controller {
	return Controller{}
}

pub fn (mut c Controller) open_document(file_path string) !int {
	c.docs[0] = Document.new(file_path)!
	return 0
}

pub fn (c Controller) get_iterator(doc_id int) LineIterator {
	return c.docs[0].iter()
}

pub fn (mut c Controller) free() {
	unsafe { c.docs.free( )}
}

@[heap]
pub struct Document {
	data buffers.GapBuffer
}

fn Document.new(file_path string) !Document {
	return Document{
		data: buffers.GapBuffer.new(content: (iconv.read_file_encoding(file_path, "UTF-8") or { return error("failed to read file ${file_path}: ${err}") }).runes())
	}
}

pub fn (d Document) iter() LineIterator {
	return d.data.iter()
}

pub interface LineIterator {
mut:
	next() ?[]rune
}

