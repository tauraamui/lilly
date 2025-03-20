// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
