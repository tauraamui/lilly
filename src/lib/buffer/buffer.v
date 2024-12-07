module buffer

import history { History }
import os

pub struct Buffer {
pub:
	file_path string
pub mut:
	lines            []string
	auto_close_chars []string
mut:
	c_buffer   GapBuffer
	// line_tracker LineTracker
}

pub fn (mut buffer Buffer) load_from_path() ! {
	buffer.lines = os.read_lines(buffer.file_path) or {
		return error('unable to open file ${buffer.file_path} ${err}')
	}
	if buffer.lines.len == 0 {
		buffer.lines = ['']
	}
	// TODO(tauraamui): enable this additional loading under a flag
	/*
	file_contents := os.read_file(buffer.file_path) or { return error("unable to open file ${buffer.file_path}: ${err}") }
	buffer.c_buffer = GapBuffer.new(file_contents)
	*/
}

pub fn (mut buffer Buffer) iterator() LineIterator {
	return LineIterator{
		data: buffer.c_buffer.str()
	}
}

