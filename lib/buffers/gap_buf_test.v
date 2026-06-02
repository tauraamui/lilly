module buffers

import gap

fn test_insert_into_gap_results_in_expected_string() {
	mut b := gap.Buffer.new(512)
	b.insert(u8(`c`))
	assert b.str() == 'c'
}

@[assert_continues]
fn test_insert_into_gap_then_move_cursor_left() {
	mut b := gap.Buffer.new(8)
	b.insert(u8(`c`))
	assert b.str() == 'c'
	assert b.rawstr() == 'c_______'

	b.move_cur_left()
	assert b.str() == 'c'
	assert b.rawstr() == '_______c'
}

@[assert_continues]
fn test_insert_into_gap_then_move_cursor_left_multiple_times() {
	mut b := gap.Buffer.new(8)
	b.insert(u8(`c`))
	assert b.str() == 'c'
	assert b.rawstr() == 'c_______'

	b.move_cur_left()
	assert b.str() == 'c'
	assert b.rawstr() == '_______c'

	b.move_cur_left()
	assert b.str() == 'c'
	assert b.rawstr() == '_______c'
}

@[assert_continues]
fn test_insert_into_gap_then_move_cursor_left_insert_char() {
	mut b := gap.Buffer.new(8)
	b.insert(u8(`c`))
	assert b.str() == 'c'
	assert b.rawstr() == 'c_______'

	b.move_cur_left()
	b.insert(u8(`b`))
	assert b.str() == 'bc'
	assert b.rawstr() == 'b______c'

	b.move_cur_left()
	b.insert(u8(`a`))
	assert b.str() == 'abc'
	assert b.rawstr() == 'a_____bc'
}

