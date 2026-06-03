module buffers

import gap

fn test_logical_len_returns_total_real_char_count() {
	mut b := gap.Buffer.new(512)
	assert b.logical_len() == 0

	b.insert(u8(`c`))
	assert b.str() == 'c'
	assert b.logical_len() == 1

	b.insert(u8(`d`))
	assert b.str() == 'cd'
	assert b.logical_len() == 2

	b.insert(u8(`e`))
	assert b.str() == 'cde'
	assert b.logical_len() == 3

	b.backspace()
	assert b.str() == 'cd'
	assert b.logical_len() == 2
}

fn test_insert_into_gap_results_in_expected_string() {
	mut b := gap.Buffer.new(512)
	b.insert(u8(`c`))
	assert b.str() == 'c'
}

fn test_insert_into_gap_then_delete_results_in_expected_string() {
	mut b := gap.Buffer.new(8)
	b.insert(u8(`c`))
	b.insert(u8(`d`))
	b.insert(u8(`e`))
	b.insert(u8(`f`))
	assert b.str() == 'cdef'
	assert b.rawstr() == 'cdef____'

	b.move_cur_left()
	b.move_cur_left()
	assert b.str() == 'cdef'
	assert b.rawstr() == 'cd____ef'

	b.delete()
	assert b.str() == 'cdf'
	assert b.rawstr() == 'cd____ef'
}

fn test_insert_into_gap_then_backspace_results_in_expected_string() {
	mut b := gap.Buffer.new(8)
	b.insert(u8(`c`))
	b.insert(u8(`d`))
	b.insert(u8(`e`))
	b.insert(u8(`f`))
	assert b.str() == 'cdef'
	assert b.rawstr() == 'cdef____'

	b.move_cur_left()
	b.move_cur_left()
	assert b.str() == 'cdef'
	assert b.rawstr() == 'cd____ef'

	b.backspace()
	assert b.str() == 'cef'
	assert b.rawstr() == 'cd____ef'
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
fn test_insert_into_gap_then_move_cursor_right() {
	mut b := gap.Buffer.new(8)
	b.insert(u8(`c`))
	assert b.str() == 'c'
	assert b.rawstr() == 'c_______'

	b.move_cur_left()
	assert b.str() == 'c'
	assert b.rawstr() == '_______c'

	b.insert(u8(`d`))
	assert b.str() == 'dc'
	assert b.rawstr() == 'd______c'

	b.move_cur_right()
	b.insert(u8(`z`))
	assert b.str() == 'dcz'
	assert b.rawstr() == 'dcz_____'
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

