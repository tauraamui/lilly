module buffer

import arrays

fn test_line_buffer_num_of_lines_with_empty_doc() {
	line_buf := LineBuffer{
		lines: []
	}
	assert line_buf.num_of_lines() == 0
}

fn test_line_buffer_num_of_lines_with_single_line_doc() {
	line_buf := LineBuffer{
		lines: ['1. first line']
	}
	assert line_buf.num_of_lines() == 1
}

fn test_line_buffer_num_of_lines_with_multi_line_doc() {
	line_buf := LineBuffer{
		lines: []string{len: 512}
	}
	assert line_buf.num_of_lines() == 512
}

fn test_line_buffer_insert_text_with_initially_empty_data() {
	mut line_buf := LineBuffer{
		lines: []
	}

	new_pos := line_buf.insert_text(Position.new(line: 0, offset: 0), '1')?
	assert new_pos == Position.new(line: 0, offset: 1)
	assert line_buf.lines == ['1']
}

fn test_line_buffer_insert_text_at_offset_higher_than_current_line_size() {
	mut line_buf := LineBuffer{
		lines: ['1. first line', '2. second line', '3. third line', '4. fourth line']
	}

	new_pos := line_buf.insert_text(Position.new(line: 1, offset: 79), ' text at end of second line')?
	assert new_pos == Position.new(line: 1, offset: 41)
	assert line_buf.lines == ['1. first line', '2. second line text at end of second line',
		'3. third line', '4. fourth line']
}

fn test_line_buffer_insert_text_at_offset_higher_than_0_when_current_line_is_empty() {
	mut line_buf := LineBuffer{
		lines: ['1. first line', '', '3. third line', '4. fourth line']
	}

	new_pos := line_buf.insert_text(Position.new(line: 1, offset: 140), ' text at end of second line')?
	assert new_pos == Position.new(line: 1, offset: 27)
	assert line_buf.lines == ['1. first line', ' text at end of second line', '3. third line',
		'4. fourth line']
}

fn test_line_buffer_insert_text_at_line_higher_than_current_data() {
	mut line_buf := LineBuffer{
		lines: ['1. first line', '2. second line', '3. third line', '4. fourth line']
	}

	new_pos := line_buf.insert_text(Position.new(line: 7, offset: 0), '8. eighth line')?
	assert new_pos == Position.new(line: 7, offset: 14)
	assert line_buf.lines == ['1. first line', '2. second line', '3. third line', '4. fourth line',
		'', '', '', '8. eighth line']
}

fn test_line_buffer_insert_text_at_start_of_existing_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line', '2. second line', '3. third line', '4. fourth line']
	}

	new_pos := line_buf.insert_text(Position.new(line: 1, offset: 0), 'prefix text on second line')?
	assert new_pos == Position.new(line: 1, offset: 26)
	assert line_buf.lines == ['1. first line', 'prefix text on second line2. second line',
		'3. third line', '4. fourth line']
}

fn test_line_buffer_insert_text_at_middle_of_existing_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line', '2. second line', '3. third line', '4. fourth line']
	}

	new_pos := line_buf.insert_text(Position.new(line: 1, offset: 7), ' middle text within second line ')?
	assert new_pos == Position.new(line: 1, offset: 39)
	assert line_buf.lines == ['1. first line', '2. seco middle text within second line nd line',
		'3. third line', '4. fourth line']
}

fn test_line_buffer_insert_text_at_end_of_existing_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line', '2. second line', '3. third line', '4. fourth line']
	}

	new_pos := line_buf.insert_text(Position.new(line: 1, offset: 14), ' text at end of second line')?
	assert new_pos == Position.new(line: 1, offset: 41)
	assert line_buf.lines == ['1. first line', '2. second line text at end of second line',
		'3. third line', '4. fourth line']
}

fn test_line_buffer_insert_tab_tabs_as_spaces_disabled() {
	mut line_buf := LineBuffer{
		lines: []
	}

	tabs_not_spaces := true
	new_pos := line_buf.insert_tab(Position.new(line: 0, offset: 0), tabs_not_spaces)?
	assert new_pos == Position.new(line: 0, offset: 1)
	assert line_buf.lines == ['\t']
}

fn test_line_buffer_insert_tab_tabs_as_spaces_enabled() {
	mut line_buf := LineBuffer{
		lines: []
	}

	tabs_not_spaces := false
	new_pos := line_buf.insert_tab(Position.new(line: 0, offset: 0), tabs_not_spaces)?
	assert new_pos == Position.new(line: 0, offset: 4)
	assert line_buf.lines == ['    ']
}

fn test_line_buffer_newline_on_empty_document() {
	mut line_buf := LineBuffer{
		lines: []
	}

	new_pos := line_buf.newline(Position.new(line: 0, offset: 0))?

	assert new_pos == Position.new(line: 1, offset: 0)
	assert line_buf.lines == ['', '']
}

fn test_line_buffer_newline_on_existing_content_from_start_of_first_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content']
	}

	new_pos := line_buf.newline(Position.new(line: 0, offset: 0))?

	assert new_pos == Position.new(line: 1, offset: 0)
	assert line_buf.lines == ['', '1. first line of content']
}

fn test_line_buffer_newline_on_existing_content_from_middle_of_first_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content']
	}

	new_pos := line_buf.newline(Position.new(line: 0, offset: 11))?

	assert new_pos == Position.new(line: 1, offset: 0)
	assert line_buf.lines == ['1. first li', 'ne of content']
}

fn test_line_buffer_newline_on_existing_content_from_end_of_first_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content']
	}

	new_pos := line_buf.newline(Position.new(line: 0, offset: 24))?

	assert new_pos == Position.new(line: 1, offset: 0)
	assert line_buf.lines == ['1. first line of content', '']
}

fn test_line_buffer_newline_on_existing_content_within_middle_of_second_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content']
	}

	new_pos := line_buf.newline(Position.new(line: 1, offset: 13))?

	assert new_pos == Position.new(line: 2, offset: 0)
	assert line_buf.lines == ['1. first line of content', '2. second lin', 'e of content']
}

fn test_line_buffer_newline_on_existing_content_within_middle_of_second_line_of_three_lines() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	new_pos := line_buf.newline(Position.new(line: 1, offset: 13))?

	assert new_pos == Position.new(line: 2, offset: 0)
	assert line_buf.lines == ['1. first line of content', '2. second lin', 'e of content',
		'3. third line of content']
}

fn test_line_buffer_newline_on_existing_content_from_end_of_second_line_which_is_indented() {
	mut line_buf := LineBuffer{
		lines: ['fn function_definition() {', '    assert x == 100 && y == 20']
	}

	new_pos := line_buf.newline(Position.new(line: 1, offset: 30))?

	assert new_pos == Position.new(line: 2, offset: 4)
	assert line_buf.lines == ['fn function_definition() {', '    assert x == 100 && y == 20', '    ']
}

fn test_line_buffer_newline_on_existing_content_from_middle_of_second_line_which_is_indented_with_trailing_content() {
	mut line_buf := LineBuffer{
		lines: ['fn function_definition() {', '    assert x == 100 && y == 20']
	}

	new_pos := line_buf.newline(Position.new(line: 1, offset: 15))?

	assert new_pos == Position.new(line: 2, offset: 4)
	assert line_buf.lines == ['fn function_definition() {', '    assert x ==', '     100 && y == 20']
}

fn test_line_buffer_x_on_existing_content_from_end_of_first_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content']
	}

	new_pos := line_buf.x(Position.new(line: 0, offset: 23))

	assert new_pos == Position.new(line: 0, offset: 23)
	assert line_buf.lines == ['1. first line of conten']
}

fn test_line_buffer_x_on_existing_content_from_start_of_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content']
	}

	new_pos := line_buf.x(Position.new(line: 0, offset: 0))

	assert new_pos == Position.new(line: 0, offset: 0)
	assert line_buf.lines == ['. first line of content']
}

fn test_line_buffer_backspace_on_existing_content_from_start_of_first_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content']
	}

	new_pos := line_buf.backspace(Position.new(line: 0, offset: 0))?

	assert new_pos == Position.new(line: 0, offset: 0)
	assert line_buf.lines == ['1. first line of content']
}

fn test_line_buffer_backspace_on_existing_content_from_end_of_first_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content']
	}

	mut new_pos := line_buf.backspace(Position.new(line: 0, offset: 23))?

	assert new_pos == Position.new(line: 0, offset: 22)
	assert line_buf.lines == ['1. first line of conten']

	new_pos = line_buf.backspace(new_pos)?

	assert new_pos == Position.new(line: 0, offset: 21)
	assert line_buf.lines == ['1. first line of conte']
}

fn test_line_buffer_backspace_on_existing_content_from_end_of_line_initial_pos_way_oob() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content']
	}

	mut new_pos := line_buf.backspace(Position.new(line: 81, offset: 60))?

	assert new_pos == Position.new(line: 0, offset: 22)
	assert line_buf.lines == ['1. first line of conten']

	new_pos = line_buf.backspace(new_pos)?

	assert new_pos == Position.new(line: 0, offset: 21)
	assert line_buf.lines == ['1. first line of conte']
}

fn test_line_buffer_backspace_on_existing_content_from_start_of_second_line_of_three() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.backspace(Position.new(line: 1, offset: 0))?

	assert new_pos == Position.new(line: 0, offset: 23)
	assert line_buf.lines == ['1. first line of content2. second line of content',
		'3. third line of content']

	new_pos = line_buf.backspace(new_pos)?

	assert new_pos == Position.new(line: 0, offset: 22)
	assert line_buf.lines == ['1. first line of conten2. second line of content',
		'3. third line of content']

	new_pos = line_buf.backspace(new_pos)?

	assert new_pos == Position.new(line: 0, offset: 21)
	assert line_buf.lines == ['1. first line of conte2. second line of content',
		'3. third line of content']

	new_pos = line_buf.backspace(new_pos)?

	assert new_pos == Position.new(line: 0, offset: 20)
	assert line_buf.lines == ['1. first line of cont2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_backspace_on_existing_content_from_start_of_second_line_of_three_insert_newline() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.backspace(Position.new(line: 1, offset: 0))?

	assert new_pos == Position.new(line: 0, offset: 23)
	assert line_buf.lines == ['1. first line of content2. second line of content',
		'3. third line of content']

	new_pos = line_buf.backspace(new_pos)?

	assert new_pos == Position.new(line: 0, offset: 22)
	assert line_buf.lines == ['1. first line of conten2. second line of content',
		'3. third line of content']

	new_pos = line_buf.backspace(new_pos)?

	assert new_pos == Position.new(line: 0, offset: 21)
	assert line_buf.lines == ['1. first line of conte2. second line of content',
		'3. third line of content']

	new_pos = line_buf.backspace(new_pos)?

	assert new_pos == Position.new(line: 0, offset: 20)
	assert line_buf.lines == ['1. first line of cont2. second line of content',
		'3. third line of content']

	new_pos = line_buf.newline(new_pos.add(Distance{0, 1}))?

	assert new_pos == Position.new(line: 1, offset: 0)
	assert line_buf.lines == ['1. first line of cont', '2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_o_on_existing_content_from_middle_of_first_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content']
	}

	new_pos := line_buf.o(Position.new(line: 0, offset: 11))?

	assert new_pos == Position.new(line: 1, offset: 0)
	assert line_buf.lines == ['1. first line of content', '']
}

fn test_line_buffer_o_on_existing_content_from_end_of_line_initial_pos_way_oob() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content']
	}

	mut new_pos := line_buf.o(Position.new(line: 81, offset: 60))?

	assert new_pos == Position.new(line: 82, offset: 0)
	assert line_buf.lines == arrays.append(['1. first line of content'], []string{len: 82})
}

fn test_line_buffer_o_on_existing_content_from_start_of_second_line_of_three() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.o(Position.new(line: 1, offset: 0))?

	assert new_pos == Position.new(line: 2, offset: 0)
	assert line_buf.lines == ['1. first line of content', '2. second line of content', '',
		'3. third line of content']

	new_pos = line_buf.o(new_pos)?

	assert new_pos == Position.new(line: 3, offset: 0)
	assert line_buf.lines == ['1. first line of content', '2. second line of content', '', '',
		'3. third line of content']

	new_pos = line_buf.o(new_pos)?

	assert new_pos == Position.new(line: 4, offset: 0)
	assert line_buf.lines == ['1. first line of content', '2. second line of content', '', '',
		'', '3. third line of content']

	new_pos = line_buf.o(new_pos)?

	assert new_pos == Position.new(line: 5, offset: 0)
	assert line_buf.lines == ['1. first line of content', '2. second line of content', '', '',
		'', '', '3. third line of content']
}

fn test_line_buffer_left_on_no_content() {
	mut line_buf := LineBuffer{
		lines: []
	}

	mut new_pos := line_buf.left(Position.new(line: 0, offset: 0))?

	assert new_pos == Position.new(line: 0, offset: 0)
}

fn test_line_buffer_left_on_existing_content_from_start_of_first_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.left(Position.new(line: 0, offset: 0))?

	assert new_pos == Position.new(line: 0, offset: 0)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_left_on_existing_content_from_start_of_second_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.left(Position.new(line: 1, offset: 0))?

	assert new_pos == Position.new(line: 1, offset: 0)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_left_on_existing_content_from_middle_of_second_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.left(Position.new(line: 1, offset: 12))?

	assert new_pos == Position.new(line: 1, offset: 11)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']

	new_pos = line_buf.left(new_pos)?

	assert new_pos == Position.new(line: 1, offset: 10)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_right_on_no_content() {
	mut line_buf := LineBuffer{
		lines: []
	}

	mut new_pos := line_buf.right(Position.new(line: 0, offset: 0), false)?

	assert new_pos == Position.new(line: 0, offset: 0)
}

fn test_line_buffer_right_on_existing_content_from_end_of_first_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.right(Position.new(line: 0, offset: 23), false)?

	assert new_pos == Position.new(line: 0, offset: 23)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_right_on_existing_content_from_start_of_second_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.right(Position.new(line: 1, offset: 0), false)?

	assert new_pos == Position.new(line: 1, offset: 1)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_right_on_existing_content_from_middle_of_second_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.right(Position.new(line: 1, offset: 12), false)?

	assert new_pos == Position.new(line: 1, offset: 13)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']

	new_pos = line_buf.right(new_pos, false)?

	assert new_pos == Position.new(line: 1, offset: 14)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_down_on_no_content() {
	mut line_buf := LineBuffer{
		lines: []
	}

	mut new_pos := line_buf.down(Position.new(line: 0, offset: 0), false)?

	assert new_pos == Position.new(line: 0, offset: 0)
}

fn test_line_buffer_down_on_existing_content_from_end_of_first_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.down(Position.new(line: 0, offset: 55), false)?

	assert new_pos == Position.new(line: 1, offset: 24)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_down_on_existing_content_from_start_of_second_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.down(Position.new(line: 1, offset: 0), false)?

	assert new_pos == Position.new(line: 2, offset: 0)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_down_on_existing_content_from_middle_of_second_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.down(Position.new(line: 1, offset: 12), false)?

	assert new_pos == Position.new(line: 2, offset: 12)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']

	new_pos = line_buf.down(new_pos, false)?

	assert new_pos == Position.new(line: 2, offset: 12)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_down_insert_mode_on_no_content() {
	mut line_buf := LineBuffer{
		lines: []
	}

	mut new_pos := line_buf.down(Position.new(line: 0, offset: 0), true)?

	assert new_pos == Position.new(line: 0, offset: 0)
}

fn test_line_buffer_down_insert_mode_on_existing_content_from_end_of_first_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.down(Position.new(line: 0, offset: 55), true)?

	assert new_pos == Position.new(line: 1, offset: 25)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_down_insert_mode_on_existing_content_from_start_of_second_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.down(Position.new(line: 1, offset: 0), true)?

	assert new_pos == Position.new(line: 2, offset: 0)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_down_insert_mode_on_existing_content_from_middle_of_second_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.down(Position.new(line: 1, offset: 12), true)?

	assert new_pos == Position.new(line: 2, offset: 12)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']

	new_pos = line_buf.down(new_pos, false)?

	assert new_pos == Position.new(line: 2, offset: 12)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_up_on_no_content() {
	mut line_buf := LineBuffer{
		lines: []
	}

	mut new_pos := line_buf.up(Position.new(line: 0, offset: 0), false)?

	assert new_pos == Position.new(line: 0, offset: 0)
}

fn test_line_buffer_up_on_existing_content_from_end_of_first_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.up(Position.new(line: 1, offset: 55), false)?

	assert new_pos == Position.new(line: 0, offset: 23)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_up_on_existing_content_from_start_of_second_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.up(Position.new(line: 2, offset: 0), false)?

	assert new_pos == Position.new(line: 1, offset: 0)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_up_on_existing_content_from_middle_of_second_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.up(Position.new(line: 2, offset: 12), false)?

	assert new_pos == Position.new(line: 1, offset: 12)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']

	new_pos = line_buf.up(new_pos, false)?

	assert new_pos == Position.new(line: 0, offset: 12)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_up_insert_mode_on_no_content() {
	mut line_buf := LineBuffer{
		lines: []
	}

	mut new_pos := line_buf.up(Position.new(line: 0, offset: 0), true)?

	assert new_pos == Position.new(line: 0, offset: 0)
}

fn test_line_buffer_up_insert_mode_on_existing_content_from_end_of_first_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.up(Position.new(line: 1, offset: 55), true)?

	assert new_pos == Position.new(line: 0, offset: 24)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_up_insert_mode_on_existing_content_from_start_of_second_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.up(Position.new(line: 2, offset: 0), true)?

	assert new_pos == Position.new(line: 1, offset: 0)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_up_insert_mode_on_existing_content_from_middle_of_second_line() {
	mut line_buf := LineBuffer{
		lines: ['1. first line of content', '2. second line of content', '3. third line of content']
	}

	mut new_pos := line_buf.up(Position.new(line: 2, offset: 12), true)?

	assert new_pos == Position.new(line: 1, offset: 12)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']

	new_pos = line_buf.up(new_pos, false)?

	assert new_pos == Position.new(line: 0, offset: 12)
	assert line_buf.lines == ['1. first line of content', '2. second line of content',
		'3. third line of content']
}

fn test_line_buffer_up_to_next_blank_line_on_no_content() {
	mut line_buf := LineBuffer{
		lines: []
	}

	assert line_buf.up_to_next_blank_line(Position.new(line: 0, offset: 0)) == none
}

fn test_line_buffer_up_to_next_blank_line_on_existing_content_from_end_of_last_line() {
	mut line_buf := LineBuffer{
		lines: ['This is a doc', '1. first line', '', '2. second line', '3. third line',
			'5. fifth line']
	}

	new_pos := line_buf.up_to_next_blank_line(Position.new(line: 5, offset: 321))? // line y: 5, x: 321 so oobs

	assert new_pos == Position.new(line: 2, offset: 0)
	assert line_buf.lines == ['This is a doc', '1. first line', '', '2. second line', '3. third line',
		'5. fifth line']
}

fn test_line_buffer_up_to_next_blank_line_on_existing_content_from_start_of_fourth_line() {
	mut line_buf := LineBuffer{
		lines: ['This is a doc', '1. first line', '', '2. second line', '3. third line',
			'5. fifth line']
	}

	new_pos := line_buf.up_to_next_blank_line(Position.new(line: 4, offset: 0))?

	assert new_pos == Position.new(line: 2, offset: 0)
	assert line_buf.lines == ['This is a doc', '1. first line', '', '2. second line', '3. third line',
		'5. fifth line']
}

fn test_line_buffer_up_to_next_blank_line_on_existing_content_from_middle_of_second_line() {
	mut line_buf := LineBuffer{
		lines: ['This is a doc', '1. first line', '', '2. second line', '3. third line',
			'5. fifth line']
	}

	assert line_buf.up_to_next_blank_line(Position.new(line: 1, offset: 12)) == none
	assert line_buf.lines == ['This is a doc', '1. first line', '', '2. second line', '3. third line',
		'5. fifth line']
}

fn test_line_buffer_down_to_next_blank_line_on_no_content() {
	mut line_buf := LineBuffer{
		lines: []
	}

	assert line_buf.down_to_next_blank_line(Position.new(line: 0, offset: 0)) == none
}

fn test_line_buffer_down_to_next_blank_line_on_existing_content_from_end_of_last_line() {
	mut line_buf := LineBuffer{
		lines: ['This is a doc', '1. first line', '', '2. second line', '3. third line',
			'5. fifth line']
	}

	new_pos := line_buf.down_to_next_blank_line(Position.new(line: 0, offset: 321))? // line y: 1, x: 321 so oobs

	assert new_pos == Position.new(line: 2, offset: 0)
	assert line_buf.lines == ['This is a doc', '1. first line', '', '2. second line', '3. third line',
		'5. fifth line']
}

fn test_line_buffer_down_to_next_blank_line_on_existing_content_from_start_of_fourth_line() {
	mut line_buf := LineBuffer{
		lines: ['This is a doc', '1. first line', '', '2. second line', '3. third line',
			'5. fifth line']
	}

	assert line_buf.down_to_next_blank_line(Position.new(line: 4, offset: 0)) == none
	assert line_buf.lines == ['This is a doc', '1. first line', '', '2. second line', '3. third line',
		'5. fifth line']
}

fn test_line_buffer_down_to_next_blank_line_on_existing_content_from_middle_of_second_line() {
	mut line_buf := LineBuffer{
		lines: ['This is a doc', '1. first line', '', '2. second line', '3. third line',
			'5. fifth line']
	}

	assert line_buf.down_to_next_blank_line(Position.new(line: 1, offset: 12))? == Position.new(
		line:   3
		offset: 0
	)
	assert line_buf.lines == ['This is a doc', '1. first line', '', '2. second line', '3. third line',
		'5. fifth line']
}
