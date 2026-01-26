module documents

import lib.buffers

@[heap]
pub struct Document {
	data buffers.GapBuffer
}

pub fn Document.new(file_path string) !Document {
}

pub fn (d Document) iter() LineIterator {
	return d.data.iter()
}

pub interface LineIterator {
mut:
	next() ?[]rune
}

