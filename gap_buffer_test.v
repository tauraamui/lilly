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
	}
}

