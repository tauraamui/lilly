module main

fn test_inserting_into_gap_buffer() {
	mut gb := GapBuffer.new()
	assert gb.raw_str() == '_'.repeat(gap_size) // if the buffer is empty, str shows just the gap

	gb.insert('12345') // insert a string which is 1 char less than the gap size
	assert gb.empty_gap_space_size() == 1
	assert gb.raw_str() == '12345_' // so we can see the gap is "nearly full", but one space is left

	gb.insert('6')
	assert gb.empty_gap_space_size() == gap_size
	assert gb.raw_str() == '123456${'_'.repeat(gap_size)}' // thanks to resizing gap is now back to "gap size" post cursor loc
}

fn test_inserting_into_gap_buffer_and_then_backspacing() {
	mut gb := GapBuffer.new()
	assert gb.raw_str() == '_'.repeat(gap_size) // if the buffer is empty, str shows just the gap

	gb.insert('This is a full sentence!') // insert a string which is 1 char less than the gap size
	assert gb.empty_gap_space_size() == 6
	assert gb.raw_str() == 'This is a full sentence!${'_'.repeat(gap_size)}' // so we can see the gap is "nearly full", but one space is left

	gb.backspace()
	assert gb.empty_gap_space_size() == 7
	assert gb.raw_str() == 'This is a full sentence${'_'.repeat(gap_size + 1)}' // so we can see the gap is "nearly full", but one space is left

	gb.backspace()
	gb.backspace()
	gb.backspace()
	gb.backspace()

	assert gb.empty_gap_space_size() == 11
	assert gb.raw_str() == 'This is a full sent${'_'.repeat(gap_size + 5)}' // so we can see the gap is "nearly full", but one space is left

	gb.insert('A')
	assert gb.empty_gap_space_size() == 10
	assert gb.raw_str() == 'This is a full sentA${'_'.repeat(gap_size + 4)}' // so we can see the gap is "nearly full", but one space is left
}

fn test_inserting_into_gap_buffer_and_then_deleting() {
	mut gb := GapBuffer.new()
	assert gb.raw_str() == '_'.repeat(gap_size) // if the buffer is empty, str shows just the gap

	gb.insert('This is a full sentence!') // insert a string which is 1 char less than the gap size
	assert gb.empty_gap_space_size() == 6
	assert gb.raw_str() == 'This is a full sentence!${'_'.repeat(gap_size)}' // so we can see the gap is "nearly full", but one space is left

	gb.move_cursor_left(10)
	assert gb.raw_str() == 'This is a full${'_'.repeat(gap_size)} sentence!' // so we can see the gap is "nearly full", but one space is left

	gb.delete()
	assert gb.raw_str() == 'This is a full${'_'.repeat(gap_size + 1)}sentence!' // so we can see the gap is "nearly full", but one space is left

	gb.delete()
	gb.delete()
	gb.delete()
	gb.delete()

	assert gb.raw_str() == 'This is a full${'_'.repeat(gap_size + 5)}ence!' // so we can see the gap is "nearly full", but one space is left
}

fn test_moving_cursor_left() {
	mut gb := GapBuffer.new()

	gb.insert('Some test text, here we go!')
	assert gb.empty_gap_space_size() == 3
	assert gb.raw_str() == 'Some test text, here we go!${'_'.repeat(gap_size / 2)}'

	gb.move_cursor_left(1)
	assert gb.raw_str() == 'Some test text, here we go${'_'.repeat(gap_size / 2)}!'
}

fn test_moving_cursor_right() {
	mut gb := GapBuffer.new()

	gb.insert('Some test text, here we go!')
	assert gb.empty_gap_space_size() == 3
	assert gb.raw_str() == 'Some test text, here we go!${'_'.repeat(gap_size / 2)}'

	gb.move_cursor_right(1)
	assert gb.raw_str() == 'Some test text, here we go!${'_'.repeat(gap_size / 2)}'

	gb.move_cursor_left(3)
	assert gb.raw_str() == 'Some test text, here we ${'_'.repeat(gap_size / 2)}go!'

	gb.move_cursor_right(1)
	assert gb.raw_str() == 'Some test text, here we g${'_'.repeat(gap_size / 2)}o!'
}

fn test_moving_cursor_left_and_then_insert() {
	mut gb := GapBuffer.new()

	gb.insert('Some test text, here we go!')
	assert gb.empty_gap_space_size() == 3
	assert gb.raw_str() == 'Some test text, here we go!${'_'.repeat(gap_size / 2)}'

	gb.move_cursor_left(8)
	assert gb.raw_str() == 'Some test text, her${'_'.repeat(gap_size / 2)}e we go!'

	gb.insert('??')
	assert gb.raw_str() == 'Some test text, her??_e we go!'

	gb.insert('+')
	assert gb.raw_str() == 'Some test text, her??+${'_'.repeat(gap_size)}e we go!'

	assert gb.str() == 'Some test text, her??+e we go!'
}

fn test_line_iterator() {
	mut gb := GapBuffer.new()
	gb.insert('1. This is the first line\n2. This is the second line\n3. This is the third line.')

	iter := LineIterator{
		data: gb.str()
	}
	for i, line in iter {
		match i {
			0 { assert line == '1. This is the first line' }
			1 { assert line == '2. This is the second line' }
			2 { assert line == '3. This is the third line' }
			else {}
		}
	}
}

fn test_line_iterator_with_lots_of_blank_lines() {
	mut gb := GapBuffer.new()
	gb.insert('1. This is the first line\n\n\n\n2. This is the second line\n3. This is the third line.')

	iter := LineIterator{
		data: gb.str()
	}
	for i, line in iter {
		match i {
			0 { assert line == '1. This is the first line' }
			1 { assert line == '' }
			2 { assert line == '' }
			3 { assert line == '' }
			4 { assert line == '2. This is the second line' }
			5 { assert line == '3. This is the third line' }
			else {}
		}
	}
}
