module buffer

fn test_line_buffer_insert_text_with_initially_empty_data() {
	mut line_buf := LineBuffer{
		lines: []
	}

	new_pos := line_buf.insert_text(Position.new(0, 0), "1")?
	assert new_pos == Position.new(0, 1)
	assert line_buf.lines == ["1"]
}

fn test_line_buffer_insert_text_at_line_higher_than_current_data() {
}

