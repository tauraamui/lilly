module main

fn test_inserting_into_gap_buffer() {
	mut gb := GapBuffer.new()
	assert gb.str() == "_".repeat(gap_size) // if the buffer is empty, str shows just the gap

	gb.insert("12345") // insert a string which is 1 char less than the gap size
	assert gb.str() == "12345_" // so we can see the gap is "nearly full", but one space is left

	gb.insert("6")
	assert gb.str() == "123456${'_'.repeat(gap_size)}" // thanks to resizing gap is now back to "gap size" post cursor loc
}
