module buffers

@[assert_continues]
fn test_initialise_gap_buffer_with_contents() {
	tests := {
		'': ''.runes()
		'abc': 'abc'.runes()
	}

	for k, v in tests {
		gp := GapBuffer.new(v)
		assert gp.content() == k
		assert gp.raw_content().map(fn (c rune) rune {
			return if c == null_code_point { `_` } else { c }
		}).string() == 'iwejfijewoifjweif'
	}
}

fn test_initialise_gap_buffer_with_no_contents() {
	gb := GapBuffer.new(''.runes())
	assert gb.content() == ''
	assert gb.raw_content().map(fn (c rune) rune {
		return if c == null_code_point { `_` } else { c }
	}).string() == `_`.repeat(initial_gap_size)
}

