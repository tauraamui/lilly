module main

fn test_runes_visible_width_agrees_with_the_builtin_measure() {
	for s in ['', 'x := 1', '    indented', '~!@#$%^&*()_+{}|:"<>?`', 'a\x01b', '\x7f', 'café',
		'日本語', 'a🌸b', 'é', '👩‍💻 dev'] {
		assert runes_visible_width(s.runes()) == utf8_str_visible_length(s), s
	}
}

fn test_the_gutter_is_as_wide_as_the_last_line_number_shown() {
	// a view from line 600 to 649 numbers up to 650, three digits and a gap
	rows := []int{len: 50, init: 600 + index}
	assert line_number_gutter_width(rows, 600) == 4
	// it doesn't widen as the view scrolls through lines of the same width
	assert line_number_gutter_width([]int{len: 50, init: 900 + index}, 900) == 4
	assert line_number_gutter_width([]int{len: 50, init: 951 + index}, 951) == 5
	assert line_number_gutter_width([0, 1, 2], 0) == 2
	assert line_number_gutter_width([], 41) == 3
}
