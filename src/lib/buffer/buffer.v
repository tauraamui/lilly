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
}

