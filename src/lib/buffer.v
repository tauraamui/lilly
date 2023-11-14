module lib

import history { History }

pub struct Buffer {
pub mut:
	lines     []string
mut:
	lines_cpy []string
	history   History
}

pub fn (mut buffer Buffer) undo() {
}

pub fn (mut buffer Buffer) snapshot() {
	buffer.lines_cpy = buffer.lines.clone()
}

pub fn (mut buffer Buffer) update_undo_history() {
	buffer.history.append_ops_to_undo(buffer.lines_cpy, buffer.lines)
}

