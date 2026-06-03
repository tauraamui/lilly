module documents

import lib.buffers

@[heap]
pub struct Controller2 {
	docs map[int]buffers.TextBuffer
}

pub fn (mut c Controller2) open_document(path string) !int {
	return error('')
}

