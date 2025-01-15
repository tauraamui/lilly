module telescope

import os

const pattern = r'(\w{4,6})\((\w*)\)\s+\[(\d+/\d+/\d+)\]'

fn test_exec_rg_with_pattern_check_execute_invoked_correctly() {
	mock_exec := fn (cmd string) os.Result {
		if cmd != "rg '${pattern}'" {
			return os.Result{ exit_code: 1 }
		}
		return os.Result{ exit_code: 0 }
	}
	assert exec_rg(mock_exec, pattern).exit_code == 0
}
