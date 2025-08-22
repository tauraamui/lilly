// Copyright 2024 The Lilly Editor contributors
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

module buffer

fn test_read_range_of_full_lines_across_multiple_lines() {
	mut gb := GapBuffer.new('1. First line that has more content\n2. Second line!\n3. Third line :3')

	mut start_pos := Position.new(line: 0, offset: 4)
	mut end_pos := start_pos.add(Distance{ lines: 1, offset: 7 })
	assert gb.read(Range.new(start_pos, end_pos))? == 'irst line that has more content\n2. Second l'

	start_pos = Position.new(line: 1, offset: 0)
	end_pos = gb.find_end_of_line2(start_pos.add(Distance{ lines: 1 }))?
	assert gb.read(Range.new(start_pos, end_pos))? == '2. Second line!\n3. Third line :3'
}

fn test_read_range_of_partials_of_each_line_from_document_with_content() {
	mut gb := GapBuffer.new('1. First line that has more content\n2. Second line!\n3. Third line :3')

	mut start_pos := Position.new(line: 0, offset: 4)
	mut end_pos := start_pos.add(Distance{ offset: 7 })
	assert gb.read(Range.new(start_pos, end_pos))? == 'irst li'

	start_pos = Position.new(line: 1, offset: 0)
	end_pos = start_pos.add(Distance{ offset: 8 })
	assert gb.read(Range.new(start_pos, end_pos))? == '2. Secon'

	start_pos = Position.new(line: 2, offset: 9)
	end_pos = start_pos.add(Distance{ offset: 7 })
	assert gb.read(Range.new(start_pos, end_pos))? == 'line :3'
}

fn test_read_range_of_each_full_line_from_document_with_content() {
	mut gb := GapBuffer.new('1. First line\n2. Second line!\n3. Third line :3')

	mut start_pos := Position.new(line: 0, offset: 0)
	mut end_pos := gb.find_end_of_line2(start_pos)?
	assert gb.read(Range.new(start_pos, end_pos))? == '1. First line'

	start_pos = Position.new(line: 1, offset: 0)
	end_pos = gb.find_end_of_line2(start_pos)?
	assert gb.read(Range.new(start_pos, end_pos))? == '2. Second line!'

	start_pos = Position.new(line: 2, offset: 0)
	end_pos = gb.find_end_of_line2(start_pos)?
	assert gb.read(Range.new(start_pos, end_pos))? == '3. Third line :3'
}

fn test_up_to_next_blank_line_in_document_with_no_blank_line_given_cursor_at_top() {
	mut gb := GapBuffer.new('1. First line\n2. Second line!\n3. Third line :3')
	new_pos := gb.up_to_next_blank_line(Pos{ x: 0, y: 0 })
	assert new_pos == none
}

fn test_up_to_next_blank_line_in_document_with_blank_line_below_the_cursor_at_top() {
	mut gb := GapBuffer.new('1. First line\n\n2. Second line!\n3. Third line :3')
	new_pos := gb.up_to_next_blank_line(Pos{ x: 0, y: 0 })
	assert new_pos == none
}

fn test_up_to_next_blank_line_in_document_with_blank_line_above_the_cursor_in_middle() {
	mut gb := GapBuffer.new('1. First line\n\n2. Second line!\n3. Third line :3')
	assert gb.up_to_next_blank_line(Pos{ x: 0, y: 3 })? == Pos{
		x: 0
		y: 1
	}
}

fn test_inserting_into_gap_buffer() {
	mut gb := GapBuffer.new('12345')

	assert gb.raw_str() == '${'_'.repeat(gap_size)}12345'

	gb.move_data_cursor_right(gb.data.len - gb.gap_end) // move gap to end of the data

	for c in '6'.runes() {
		gb.insert(c)
	}
	assert gb.raw_str() == '123456${'_'.repeat(gap_size - 1)}'
}

fn test_inserting_into_gap_buffer_and_then_backspacing() {
	mut gb := GapBuffer.new('This is a full sentence!')

	gb.move_data_cursor_right(gb.data.len - gb.gap_end) // move gap to end of the data

	gb.backspace()
	assert gb.raw_str() == 'This is a full sentence${'_'.repeat(gap_size + 1)}'

	gb.backspace()
	gb.backspace()
	gb.backspace()
	gb.backspace()

	assert gb.empty_gap_space_size() == gap_size + 5 // gap_size is set as a constant within `gap_buffer.v`
	assert gb.raw_str() == 'This is a full sent${'_'.repeat(gap_size + 5)}' // so we can see the gap is "nearly full", but one space is left

	for c in 'A'.runes() {
		gb.insert(c)
	}
	assert gb.empty_gap_space_size() == gap_size + 4
	assert gb.raw_str() == 'This is a full sentA${'_'.repeat(gap_size + 4)}' // so we can see the gap is "nearly full", but one space is left
}

fn test_inserting_into_gap_buffer_and_then_deleting() {
	mut gb := GapBuffer.new('This is a full sentence!')

	gb.move_data_cursor_right(gb.data.len - gb.gap_end) // move gap to end of the data

	assert gb.raw_str() == 'This is a full sentence!${'_'.repeat(gap_size)}' // so we can see the gap is "nearly full", but one space is left

	gb.move_data_cursor_left(10)
	assert gb.raw_str() == 'This is a full${'_'.repeat(gap_size)} sentence!' // so we can see the gap is "nearly full", but one space is left

	gb.delete(false)
	assert gb.raw_str() == 'This is a full${'_'.repeat(gap_size + 1)}sentence!' // so we can see the gap is "nearly full", but one space is left

	gb.delete(false)
	gb.delete(false)
	gb.delete(false)
	gb.delete(false)

	assert gb.raw_str() == 'This is a full${'_'.repeat(gap_size + 5)}ence!' // so we can see the gap is "nearly full", but one space is left
}

fn test_moving_data_cursor_left() {
	mut gb := GapBuffer.new('Some test text, here we go!')

	gb.move_data_cursor_right(gb.data.len - gb.gap_end) // move gap to end of the data

	assert gb.raw_str() == 'Some test text, here we go!${'_'.repeat(gap_size)}'

	gb.move_data_cursor_left(1)
	assert gb.raw_str() == 'Some test text, here we go${'_'.repeat(gap_size)}!'
}

fn test_moving_data_cursor_right() {
	mut gb := GapBuffer.new('Some test text, here we go!')

	gb.move_data_cursor_right(4)
	assert gb.raw_str() == 'Some${'_'.repeat(gap_size)} test text, here we go!'

	gb.move_data_cursor_left(2)
	assert gb.raw_str() == 'So${'_'.repeat(gap_size)}me test text, here we go!'

	gb.move_data_cursor_right(1)
	assert gb.raw_str() == 'Som${'_'.repeat(gap_size)}e test text, here we go!'
}

fn test_moving_data_cursor_right_and_then_insert() {
	mut gb := GapBuffer.new('Some test text, here we go!')

	assert gb.raw_str() == '${'_'.repeat(gap_size)}Some test text, here we go!'

	gb.move_data_cursor_right(8)
	assert gb.raw_str() == 'Some tes${'_'.repeat(gap_size)}t text, here we go!'

	for c in '??'.runes() {
		gb.insert(c)
	}
	assert gb.raw_str() == 'Some tes??${'_'.repeat(gap_size - 2)}t text, here we go!'

	for c in '+'.runes() {
		gb.insert(c)
	}
	assert gb.raw_str() == 'Some tes??+${'_'.repeat(gap_size - 3)}t text, here we go!'

	assert gb.str() == 'Some tes??+t text, here we go!'
}

fn test_find_offset() {
	mut gb := GapBuffer.new('1. First line\n2. Second line!\n3. Third line :3')

	assert gb.gap_start == 0
	ggap_size := gb.gap_end - gb.gap_start
	assert gb.find_offset(Position{ line: 0, offset: 0 })! == gap_size
	assert gb.find_offset(Position{ line: 0, offset: 3 })! == gap_size + 3
	assert gb.find_offset(Position{ line: 1, offset: 0 })! == gap_size + 14
	assert gb.find_offset(Position{ line: 1, offset: 4 })! == gap_size + 18
	assert gb.in_bounds(Pos{ y: 255 }) == false
	assert gb.in_bounds(Pos{ y: 2 })
	assert gb.in_bounds(Pos{ y: 3 }) == false
}

fn test_find_end_of_line_no_starting_offset() {
	mut gb := GapBuffer.new('1. First line\n2. Second line!\n3. Third line :3')
	assert gb.find_end_of_line(Pos{ x: 0, y: 0 })! == 13
	assert gb.find_end_of_line(Pos{ x: 0, y: 1 })! == 15
	assert gb.find_end_of_line(Pos{ x: 0, y: 2 })! == 16
}

fn test_find_end_of_line2_no_starting_offset() {
	mut gb := GapBuffer.new('1. First line\n2. Second line!\n3. Third line :3')
	assert gb.find_end_of_line2(Position.new(line: 0, offset: 0))! == Position.new(
		line:   0
		offset: 13
	)
	assert gb.find_end_of_line2(Position.new(line: 1, offset: 0))! == Position.new(
		line:   1
		offset: 15
	)
	assert gb.find_end_of_line2(Position.new(line: 2, offset: 0))! == Position.new(
		line:   2
		offset: 16
	)
}

fn test_find_end_of_line_with_starting_offset() {
	mut gb := GapBuffer.new('1. First line\n2. Second line!\n3. Third line :3')
	assert gb.find_end_of_line(Pos{ x: 5, y: 0 })! == 8
	assert gb.find_end_of_line(Pos{ x: 9, y: 1 })! == 6
	assert gb.find_end_of_line(Pos{ x: 4, y: 2 })! == 12
}

fn test_find_end_of_line2_with_starting_offset() {
	mut gb := GapBuffer.new('1. First line\n2. Second line!\n3. Third line :3')
	assert gb.find_end_of_line2(Position.new(line: 0, offset: 5))! == Position.new(
		line:   0
		offset: 13
	)
	assert gb.find_end_of_line2(Position.new(line: 1, offset: 9))! == Position.new(
		line:   1
		offset: 15
	)
	assert gb.find_end_of_line2(Position.new(line: 2, offset: 4))! == Position.new(
		line:   2
		offset: 16
	)
}

fn test_find_start_of_next_word_with_starting_offset() {
	mut gb := GapBuffer.new('1. First line\n2. Second line!\n3. Third line :3')
	assert gb.find_next_word_start(Pos{ y: 0, x: 5 })! == Pos{
		y: 0
		x: 9
	}
}

fn test_find_end_of_next_word_with_starting_offset() {
	mut gb := GapBuffer.new('1. First line\n2. Second line!\n3. Third line :3')
	assert gb.find_next_word_end(Pos{ y: 0, x: 5 })! == Pos{
		y: 0
		x: 7
	}
}

fn test_find_end_of_next_word2_with_starting_offset() {
	mut gb := GapBuffer.new('1. First line\n2. Second line!\n3. Third line :3')
	assert gb.find_next_word_end2(Position.new(line: 0, offset: 5))! == Position.new(
		line: 0
		offset: 7
	)
}

fn test_line_iterator() {
	mut gb := GapBuffer.new('1. This is the first line.\n2. This is the second line.\n3. This is the third line.')

	iter := new_gap_buffer_line_iterator(gb)
	mut count := 0
	for i, line in iter {
		match i {
			0 {
				assert line == '1. This is the first line.'
				count += 1
			}
			1 {
				assert line == '2. This is the second line.'
				count += 1
			}
			2 {
				assert line == '3. This is the third line.'
				count += 1
			}
			else {}
		}
	}

	assert count == 3
}

fn test_line_iterator_with_lots_of_blank_lines() {
	mut gb := GapBuffer.new('1. This is the first line.\n\n\n\n2. This is the second line.\n3. This is the third line.')

	iter := new_gap_buffer_line_iterator(gb)
	mut count := 0
	for i, line in iter {
		match i {
			0 {
				assert line == '1. This is the first line.'
				count += 1
			}
			1 {
				assert line == ''
				count += 1
			}
			2 {
				assert line == ''
				count += 1
			}
			3 {
				assert line == ''
				count += 1
			}
			4 {
				assert line == '2. This is the second line.'
				count += 1
			}
			5 {
				assert line == '3. This is the third line.'
				count += 1
			}
			else {}
		}
	}

	assert count == 6
}
