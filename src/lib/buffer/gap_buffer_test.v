module buffer

fn test_inserting_into_gap_buffer() {
	mut gb := GapBuffer.new("12345")

	assert gb.raw_str() == "${'_'.repeat(gap_size)}12345"

	gb.move_cursor_right(gb.data.len - gb.gap_end) // move gap to end of the data

	gb.insert("6")
	assert gb.raw_str() == "123456${'_'.repeat(gap_size - 1)}"
}

fn test_inserting_into_gap_buffer_and_then_backspacing() {
	mut gb := GapBuffer.new("This is a full sentence!")

	gb.move_cursor_right(gb.data.len - gb.gap_end) // move gap to end of the data

	gb.backspace()
	assert gb.raw_str() == "This is a full sentence${'_'.repeat(gap_size + 1)}"

	gb.backspace()
	gb.backspace()
	gb.backspace()
	gb.backspace()

	assert gb.empty_gap_space_size() == 11
	assert gb.raw_str() == "This is a full sent${'_'.repeat(gap_size + 5)}" // so we can see the gap is "nearly full", but one space is left

	gb.insert("A")
	assert gb.empty_gap_space_size() == 10
	assert gb.raw_str() == "This is a full sentA${'_'.repeat(gap_size + 4)}" // so we can see the gap is "nearly full", but one space is left
}

fn test_inserting_into_gap_buffer_and_then_deleting() {
	mut gb := GapBuffer.new("This is a full sentence!")

	gb.move_cursor_right(gb.data.len - gb.gap_end) // move gap to end of the data

	assert gb.raw_str() == "This is a full sentence!${'_'.repeat(gap_size)}" // so we can see the gap is "nearly full", but one space is left

	gb.move_cursor_left(10)
	assert gb.raw_str() == "This is a full${'_'.repeat(gap_size)} sentence!" // so we can see the gap is "nearly full", but one space is left

	gb.delete()
	assert gb.raw_str() == "This is a full${'_'.repeat(gap_size + 1)}sentence!" // so we can see the gap is "nearly full", but one space is left

	gb.delete()
	gb.delete()
	gb.delete()
	gb.delete()

	assert gb.raw_str() == "This is a full${'_'.repeat(gap_size + 5)}ence!" // so we can see the gap is "nearly full", but one space is left
}

fn test_moving_cursor_left() {
	mut gb := GapBuffer.new("Some test text, here we go!")

	gb.move_cursor_right(gb.data.len - gb.gap_end) // move gap to end of the data

	assert gb.raw_str() == "Some test text, here we go!${'_'.repeat(gap_size)}"

	gb.move_cursor_left(1)
	assert gb.raw_str() == "Some test text, here we go${'_'.repeat(gap_size)}!"
}

fn test_moving_cursor_right() {
	mut gb := GapBuffer.new("Some test text, here we go!")

	gb.move_cursor_right(4)
	assert gb.raw_str() == "Some${'_'.repeat(gap_size)} test text, here we go!"

	gb.move_cursor_left(2)
	assert gb.raw_str() == "So${'_'.repeat(gap_size)}me test text, here we go!"

	gb.move_cursor_right(1)
	assert gb.raw_str() == "Som${'_'.repeat(gap_size)}e test text, here we go!"
}

fn test_moving_cursor_right_and_then_insert() {
	mut gb := GapBuffer.new("Some test text, here we go!")

	assert gb.raw_str() == "${'_'.repeat(gap_size)}Some test text, here we go!"

	gb.move_cursor_right(8)
	assert gb.raw_str() == "Some tes${'_'.repeat(gap_size)}t text, here we go!"

	gb.insert("??")
	assert gb.raw_str() == "Some tes??${'_'.repeat(gap_size - 2)}t text, here we go!"

	gb.insert("+")
	assert gb.raw_str() == "Some tes??+${'_'.repeat(gap_size - 3)}t text, here we go!"

	assert gb.str() == "Some tes??+t text, here we go!"
}

fn test_line_iterator() {
	mut gb := GapBuffer.new("1. This is the first line\n2. This is the second line\n3. This is the third line.")

	iter := new_gap_buffer_iterator(gb)
	for i, line in iter {
		match i {
			0 { assert line == "1. This is the first line" }
			1 { assert line == "2. This is the second line" }
			2 { assert line == "3. This is the third line" }
			else{}
		}
	}
}

fn test_line_iterator_with_lots_of_blank_lines() {
	mut gb := GapBuffer.new("1. This is the first line\n\n\n\n2. This is the second line\n3. This is the third line.")

	iter := new_gap_buffer_iterator(gb)
	for i, line in iter {
		match i {
			0 { assert line == "1. This is the first line" }
			1 { assert line == "" }
			2 { assert line == "" }
			3 { assert line == "" }
			4 { assert line == "2. This is the second line" }
			5 { assert line == "3. This is the third line" }
			else{}
		}
	}
}

