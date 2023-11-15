module buffer

import history { History }
import lib.diff { Op }

pub struct Buffer {
pub mut:
	lines     []string
mut:
	lines_cpy                 []string
	history                   History
	snapshotted_at_least_once bool
}

pub fn (mut buffer Buffer) undo() {
	op_to_undo := buffer.history.pop_undo() or { return }
	mut line_offset := 0
	match op_to_undo.kind {
		"ins" { buffer.lines.delete(op_to_undo.line_num + line_offset); line_offset -= 1 }
		"del" { buffer.lines.insert(op_to_undo.line_num + line_offset, op_to_undo.value); line_offset += 1 }
		else {}
	}
}

pub fn (mut buffer Buffer) snapshot() {
	buffer.snapshotted_at_least_once = true
	buffer.lines_cpy = buffer.lines.clone()
}

pub fn (mut buffer Buffer) update_undo_history() {
	if !buffer.snapshotted_at_least_once { return }
	buffer.history.append_ops_to_undo(buffer.lines_cpy, buffer.lines)
}

