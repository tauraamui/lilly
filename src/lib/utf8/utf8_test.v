module utf8

fn test_str_clamp_to_visible_length_match_max_to_str_len() {
	example_str := "A1B2C3D4E5"
	assert str_clamp_to_visible_length(example_str, example_str.len) == "A1B2C3D4E5"
}

fn test_str_clamp_to_visible_length_max_less_str_len() {
	example_str := "A1B2C3D4E5"
	assert str_clamp_to_visible_length(example_str, 3) == "A1B2C3D4E5"
}

