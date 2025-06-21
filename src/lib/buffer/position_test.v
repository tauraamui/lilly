module buffer

fn test_add_with_zero_line_distance() {
	mut pos := Position{ line: 1, offset: 3 }
	dist    := Distance{ lines: 0, offset: 4 }

	assert pos.add(dist) == Position{ line: 1, offset: 7 }
}

