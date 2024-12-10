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

pub fn (mut buffer Buffer) load_from_path(read_lines fn (path string) ![]string, use_gap_buffer bool) ! {
	buffer.lines = read_lines(buffer.file_path) or {
		return error('unable to open file ${buffer.file_path} ${err}')
	}
	if buffer.lines.len == 0 {
		buffer.lines = ['']
	}

	if use_gap_buffer {
		buffer.use_gap_buffer = use_gap_buffer
		file_contents := buffer.lines.join("\n")
		buffer.c_buffer = GapBuffer.new(file_contents)
	}
}

pub struct LineIterator {
}

pub fn (line_iterator LineIterator) next() ?string {
	return none
}

pub fn (buffer Buffer) line_iterator() ?LineIterator {
	if !buffer.use_gap_buffer { return none }
	return LineIterator{}
}

pub fn (buffer Buffer) gap_buffer_iterator() ?GapBufferIterator {
	if buffer.use_gap_buffer {
		return new_gap_buffer_iterator(buffer.c_buffer)
	}
	return none
}

