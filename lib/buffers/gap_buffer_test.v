module buffers

fn test_initialise_gap_buffer_with_no_contents() {
	gb := GapBuffer.new(content: ''.runes())
	assert gb.content() == ''
	assert gb.raw_content().map(null_code_point_to_str).string() == `_`.repeat(int(initial_gap_size))
}

fn test_initialise_gap_buffer_with_content() {
	gb := GapBuffer.new(content: 'abcdef'.runes())
	assert gb.content() == 'abcdef'
	assert gb.raw_content().map(null_code_point_to_str).string() == '${`_`.repeat(int(initial_gap_size))}abcdef'
}

fn test_insert_char_into_gap_buffer_with_no_existing_content() {
	mut gb := GapBuffer.new(content: ''.runes())
	gb.insert_char(`z`)
	assert gb.content() == 'z'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'z${`_`.repeat(int(initial_gap_size - 1))}'
}

fn test_insert_char_into_gap_buffer_with_existing_content() {
	mut gb := GapBuffer.new(content: 'abcdef'.runes())
	gb.insert_char(`z`)
	assert gb.content() == 'zabcdef'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'z${`_`.repeat(int(initial_gap_size - 1))}abcdef'
}

fn test_insert_char_into_gap_buffer_with_existing_content_with_custom_gap_size() {
	mut gb := GapBuffer.new(content: 'abcdef'.runes(), gap_size: 3)
	gb.insert_char(`z`)
	assert gb.content() == 'zabcdef'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'z__abcdef'
}

@[assert_continues]
fn test_insert_char_into_gap_buffer_with_existing_content_overflow_gap_grows_gap() {
	mut gb := GapBuffer.new(content: 'abcdef'.runes(), gap_size: 3)
	gb.insert_char(`z`)
	assert gb.content() == 'zabcdef'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'z__abcdef'

	gb.insert_char(`1`)
	assert gb.content() == 'z1abcdef'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'z1_abcdef'

	gb.insert_char(`2`)
	assert gb.content() == 'z12abcdef'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'z12abcdef'

	gb.insert_char(`3`)
	assert gb.content() == 'z123abcdef'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'z123__abcdef'
}

@[assert_continues]
fn test_insert_char_into_gap_buffer_with_existing_content_overflow_gap_grows_gap_consistently() {
	mut gb := GapBuffer.new(content: 'abcdef'.runes(), gap_size: 3)
	gb.insert_char(`z`)
	assert gb.content() == 'zabcdef'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'z__abcdef'

	gb.insert_char(`1`)
	assert gb.content() == 'z1abcdef'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'z1_abcdef'

	gb.insert_char(`2`)
	assert gb.content() == 'z12abcdef'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'z12abcdef'

	gb.insert_char(`3`)
	assert gb.content() == 'z123abcdef'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'z123__abcdef'

	gb.insert_char(`4`)
	assert gb.content() == 'z1234abcdef'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'z1234_abcdef'

	gb.insert_char(`5`)
	assert gb.content() == 'z12345abcdef'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'z12345abcdef'

	gb.insert_char(`6`)
	assert gb.content() == 'z123456abcdef'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'z123456__abcdef'
}

@[assert_continues]
fn test_move_gap_buffer_simplest_case() {
	mut gb := GapBuffer.new(content: 'abcdefghijk'.runes(), gap_size: 3)
	assert gb.content() == 'abcdefghijk'
	assert gb.raw_content().map(null_code_point_to_str).string() == '___abcdefghijk'

	gb.move_gap(1)
	assert gb.content() == 'abcdefghijk'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'a___bcdefghijk'
}

@[assert_continues]
fn test_move_gap_buffer_to_middle() {
	mut gb := GapBuffer.new(content: 'abcdefghijk'.runes(), gap_size: 3)
	assert gb.content() == 'abcdefghijk'
	assert gb.raw_content().map(null_code_point_to_str).string() == '___abcdefghijk'

	gb.move_gap(5)
	assert gb.content() == 'abcdefghijk'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'abcde___fghijk'
}

@[assert_continues]
fn test_move_gap_buffer_to_middle_and_back() {
	mut gb := GapBuffer.new(content: 'abcdefghijk'.runes(), gap_size: 3)
	assert gb.content() == 'abcdefghijk'
	assert gb.raw_content().map(null_code_point_to_str).string() == '___abcdefghijk'

	gb.move_gap(5)
	assert gb.content() == 'abcdefghijk'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'abcde___fghijk'

	gb.move_gap(0)
	assert gb.content() == 'abcdefghijk'
	assert gb.raw_content().map(null_code_point_to_str).string() == '___abcdefghijk'
}

@[assert_continues]
fn test_move_gap_buffer_to_middle_end_and_back() {
	mut gb := GapBuffer.new(content: 'abcdefghijk'.runes(), gap_size: 3)
	assert gb.content() == 'abcdefghijk'
	assert gb.raw_content().map(null_code_point_to_str).string() == '___abcdefghijk'

	gb.move_gap(5)
	assert gb.content() == 'abcdefghijk'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'abcde___fghijk'

	gb.move_gap(gb.content().runes().len)
	assert gb.content() == 'abcdefghijk'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'abcdefghijk___'

	gb.move_gap(5)
	assert gb.content() == 'abcdefghijk'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'abcde___fghijk'

	gb.move_gap(0)
	assert gb.content() == 'abcdefghijk'
	assert gb.raw_content().map(null_code_point_to_str).string() == '___abcdefghijk'
}

@[assert_continues]
fn test_move_gap_buffer_to_middle_and_back_alongside_inserts() {
	mut gb := GapBuffer.new(content: 'abcdefghijk'.runes(), gap_size: 3)
	assert gb.content() == 'abcdefghijk'
	assert gb.raw_content().map(null_code_point_to_str).string() == '___abcdefghijk'

	gb.move_gap(5)
	gb.insert_char(`1`)
	assert gb.content() == 'abcde1fghijk'
	assert gb.raw_content().map(null_code_point_to_str).string() == 'abcde1__fghijk'

	gb.move_gap(0)
	gb.insert_char(`2`)
	assert gb.content() == '2abcde1fghijk'
	assert gb.raw_content().map(null_code_point_to_str).string() == '2_abcde1fghijk'

	gb.move_gap(gb.content().runes().len)
	gb.insert_char(`3`)
	assert gb.content() == '2abcde1fghijk3'
	assert gb.raw_content().map(null_code_point_to_str).string() == '2abcde1fghijk3'

	gb.insert_char(`4`)
	assert gb.content() == '2abcde1fghijk34'
	assert gb.raw_content().map(null_code_point_to_str).string() == '2abcde1fghijk34__'

	gb.move_gap(5)
	gb.insert_char(`5`)
	assert gb.content() == '2abcd5e1fghijk34'
	assert gb.raw_content().map(null_code_point_to_str).string() == '2abcd5_e1fghijk34'
}

@[assert_continues]
fn test_gap_buffer_get_char_at() {
	mut gb := GapBuffer.new(content: 'import lib.buffers'.runes(), gap_size: 3)

	assert gb.get_char_at(x: 0, y: 0)? == `i`
	assert gb.get_char_at(x: 1, y: 0)? == `m`
	assert gb.get_char_at(x: 2, y: 0)? == `p`
	assert gb.get_char_at(x: 3, y: 0)? == `o`
	assert gb.get_char_at(x: 4, y: 0)? == `r`
	assert gb.get_char_at(x: 5, y: 0)? == `t`
	assert gb.get_char_at(x: 6, y: 0)? == ` `
}

@[assert_continues]
fn test_gap_buffer_get_char_at_multi_line_content() {
	mut gb := GapBuffer.new(content: 'import\nlib.buffers'.runes(), gap_size: 3)

	assert gb.get_char_at(x: 0, y: 0)? == `i`
	assert gb.get_char_at(x: 1, y: 0)? == `m`
	assert gb.get_char_at(x: 2, y: 0)? == `p`
	assert gb.get_char_at(x: 3, y: 0)? == `o`
	assert gb.get_char_at(x: 4, y: 0)? == `r`
	assert gb.get_char_at(x: 5, y: 0)? == `t`

	assert gb.get_char_at(x: 0, y: 1)? == `l`
	assert gb.get_char_at(x: 1, y: 1)? == `i`
	assert gb.get_char_at(x: 2, y: 1)? == `b`
	assert gb.get_char_at(x: 3, y: 1)? == `.`
	assert gb.get_char_at(x: 4, y: 1)? == `b`
	assert gb.get_char_at(x: 5, y: 1)? == `u`
	assert gb.get_char_at(x: 6, y: 1)? == `f`
	assert gb.get_char_at(x: 7, y: 1)? == `f`
	assert gb.get_char_at(x: 8, y: 1)? == `e`
	assert gb.get_char_at(x: 9, y: 1)? == `r`
	assert gb.get_char_at(x: 10, y: 1)? == `s`
}


/*
@[assert_continues]
fn test_gap_buffer_single_line_content_cursor_to_offset() {
	mut gb := GapBuffer.new(content: 'import lib.buffers'.runes(), gap_size: 3)
	assert gb.cursor_to_offset(x: 8)? == 7
	// sanity check
	assert gb.cursor_to_offset(x: 8)? == 7

	gb.move_gap(gb.data.len / 2)
	assert gb.cursor_to_offset(x: 8)? == 7
}

@[assert_continues]
fn test_gap_buffer_single_line_content_cursor_to_offset_insert_twice() {
	mut gb := GapBuffer.new(content: 'import lib.buffers'.runes(), gap_size: 3)

	gb.move_gap(gb.cursor_to_offset(x: 8) or { -1 }) // will panic if -1 is used
	gb.insert_char(`^`)
	assert gb.content() == 'import ^lib.buffers'

	gb.move_gap(gb.cursor_to_offset(x: 1) or { -1 })
	gb.insert_char(`*`)
	assert gb.content() == '*import ^lib.buffers'
}
*/

