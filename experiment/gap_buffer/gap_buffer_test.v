module main

fn test_inserting_into_gap_buffer() {
	mut gb := GapBuffer.new()
	assert gb.raw_str() == "_".repeat(gap_size) // if the buffer is empty, str shows just the gap

	gb.insert("12345") // insert a string which is 1 char less than the gap size
	assert gb.empty_gap_space_size() == 1
	assert gb.raw_str() == "12345_" // so we can see the gap is "nearly full", but one space is left

	gb.insert("6")
	assert gb.empty_gap_space_size() == gap_size
	assert gb.raw_str() == "123456${'_'.repeat(gap_size)}" // thanks to resizing gap is now back to "gap size" post cursor loc
}

fn test_moving_cursor_left() {
	mut gb := GapBuffer.new()

	gb.insert("Some test text, here we go!")
	assert gb.empty_gap_space_size() == 3
	assert gb.raw_str() == "Some test text, here we go!${'_'.repeat(gap_size / 2)}"

	gb.move_cursor_left(1)
	assert gb.raw_str() == "Some test text, here we go${'_'.repeat(gap_size / 2)}!"
}
