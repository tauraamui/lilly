module buffers

fn test_initialise_gap_buffer_with_no_contents() {
	gb := GapBuffer.new(''.runes())
	assert gb.content() == ''
	assert gb.raw_content().map(null_code_point_to_str).string() == `_`.repeat(initial_gap_size)
}

fn test_initialise_gap_buffer_with_content() {
	gb := GapBuffer.new('abcdef'.runes())
	assert gb.content() == 'abcdef'
	assert gb.raw_content().map(null_code_point_to_str).string() == '${`_`.repeat(initial_gap_size)}abcdef'
}

