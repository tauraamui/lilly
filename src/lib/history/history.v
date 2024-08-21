module history

import datatypes
import lib.diff { Op }

pub struct History {
mut:
	undos datatypes.Stack[Op] // will actually be type diff.Op
	redos datatypes.Stack[Op]
}

pub fn (mut history History) pop_undo() !Op {
	undo_op := history.undos.pop() or { return error('no pending undo operations remaining') }
	history.redos.push(undo_op)
	return undo_op
}

pub fn (mut history History) append_ops_to_undo(a []string, b []string) {
	mut ops := diff.diff(a, b)

	for i := ops.len - 1; i >= 0; i-- {
		ops[i].line_num = i - 1
		if ops[i].kind == 'same' {
			continue
		}
	}

	for op in ops {
		if op.kind == 'same' {
			continue
		}
		history.undos.push(op)
	}
}
