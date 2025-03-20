module history

import lib.diff { Op }

fn test_generate_diff_ops_twixt_two_file_versions() {
	fake_file_1 := [
		'1. first existing line',
	]

	fake_file_2 := [
		'1. first existing line',
		'2. second new line which was added',
	]

	mut his := History{}
	his.append_ops_to_undo(fake_file_1, fake_file_2)

	assert his.undos.array() == [
		Op{
			line_num: 0
			value:    '2. second new line which was added'
			kind:     'ins'
		},
	]
}
