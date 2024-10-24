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
	lines_cpy                 []string
	history                   History
	snapshotted_at_least_once bool
}

pub fn (mut buffer Buffer) load_from_path() ! {
	buffer.lines = os.read_lines(buffer.file_path) or {
		return error('unable to open file ${buffer.file_path} ${err}')
	}
	if buffer.lines.len == 0 {
		buffer.lines = ['']
	}
}

pub fn (buffer Buffer) iter() LineIterator {
	return LineIterator{
		lines: &buffer.lines
	}
}

struct LineIterator {
	lines       []string
mut:
	current_idx int = -1
}

pub fn (mut iterator LineIterator) next() ?string {
	iterator.current_idx += 1
	if iterator.current_idx >= iterator.lines.len { return none }
	return iterator.lines[iterator.current_idx]
}
