module documents

import encoding.iconv
import lib.buffers

@[heap]
pub struct Document {
	data buffers.GapBuffer
}

pub fn Document.new(file_path string) !Document {
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

