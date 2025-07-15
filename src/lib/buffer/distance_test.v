module buffer

fn test_distance_from_string_of_single_line_of_data() {
	assert Distance.of_str('line') == Distance{
		lines:  0
		offset: 4
	}
}

fn test_distance_from_string_with_trailing_newline() {
	assert Distance.of_str('trailing newline\n') == Distance{
		lines:  1
		offset: 0
	}
}
