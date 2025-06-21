module buffer

fn test_add_with_zero_line_distance() {
	mut pos := Position{ line: 1, offset: 3 }
	dist    := Distance{ lines: 0, offset: 4 }

	assert pos.add(dist) == Position{ line: 1, offset: 7 }
}

fn test_add_with_zero_line_distance_diff_offset() {
	mut pos := Position{ line: 1, offset: 3 }
	dist    := Distance{ lines: 0, offset: 19 }

	assert pos.add(dist) == Position{ line: 1, offset: 22 }
}

fn test_add_with_some_line_distance() {
	mut pos := Position{ line: 1, offset: 3 }
	dist    := Distance{ lines: 12, offset: 4 }

	assert pos.add(dist) == Position{ line: 13, offset: 4 }
}

