module buffer

import os

pub struct Buffer {
pub:
	file_path string
pub mut:
	lines            []string
	auto_close_chars []string
mut:
	use_gap_buffer   bool
	c_buffer         GapBuffer
	// line_tracker LineTracker
}

pub fn (mut buffer Buffer) load_from_path(use_gap_buffer bool) ! {
	buffer.lines = os.read_lines(buffer.file_path) or {
		return error('unable to open file ${buffer.file_path} ${err}')
	}
	if buffer.lines.len == 0 {
		buffer.lines = ['']
	}

	if use_gap_buffer {
		buffer.use_gap_buffer = use_gap_buffer
		file_contents := os.read_file(buffer.file_path) or { return error("unable to open file ${buffer.file_path}: ${err}") }
		buffer.c_buffer = GapBuffer.new(file_contents)
	}
}

pub interface LineIterator {
mut:
	next() ?string
}

struct LineListIterator {
mut:
	index    int
	data_ref []string
}

pub fn (mut iter LineListIterator) next() ?string {
	if iter.index >= iter.data_ref.len {
		return none
	}
	defer { iter.index += 1 }
	return iter.data_ref[iter.index]
}

pub fn (mut buffer Buffer) iterator() LineIterator {
	if buffer.use_gap_buffer {
		return new_iterator(buffer.c_buffer)
	}
	return LineListIterator{ data_ref: buffer.lines }
}

fn new_iterator(buffer GapBuffer) GapBufferLineIterator {
	return GapBufferLineIterator{
		data: buffer.str()
	}
}

