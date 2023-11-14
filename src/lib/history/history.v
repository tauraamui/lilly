module history

import datatypes
import lib.diff { Op }

pub struct History {
mut:
	undos datatypes.Stack[Op] // will actually be type diff.Op
	redos datatypes.Stack[Op]
}

pub fn (mut history History) pop_undo() !Op {
	undo_op := history.undos.pop() or { return error("no pending undo operations remaining") }
	history.redos.push(undo_op)
	return undo_op
}

pub fn (mut history History) append_ops_to_undo(a []string, b []string) {
	ops := diff.diff(a, b)

	for i, op in ops {
		mut op_cpy := op
		if op.kind == "same" { continue }
		op_cpy.line_num = i
		history.undos.push(op_cpy)
	}
}

