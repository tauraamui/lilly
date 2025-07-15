module buffer

fn test_add_with_zero_line_distance() {
	mut pos := Position{
		line:   1
		offset: 3
	}
	dist := Distance{
		lines:  0
		offset: 4
	}

	assert pos.add(dist) == Position{
		line:   1
		offset: 7
	}
}

fn test_apply_with_zero_line_distance() {
	mut pos := Position{
		line:   1
		offset: 3
	}
	dist := Distance{
		lines:  0
		offset: 4
	}

	pos.apply(dist)
	assert pos == Position{
		line:   1
		offset: 7
	}
}

fn test_add_with_zero_line_distance_diff_offset() {
	mut pos := Position{
		line:   1
		offset: 3
	}
	dist := Distance{
		lines:  0
		offset: 19
	}

	assert pos.add(dist) == Position{
		line:   1
		offset: 22
	}
}

fn test_add_with_some_line_distance() {
	mut pos := Position{
		line:   1
		offset: 3
	}
	dist := Distance{
		lines:  12
		offset: 4
	}

	assert pos.add(dist) == Position{
		line:   13
		offset: 7
	}
}

fn test_less_than_works_when_position_a_less_then_b() {
	earlier_position := Position{
		line:   2
		offset: 20
	}
	later_position := Position{
		line:   3
		offset: 10
	}

	assert earlier_position < later_position
}

fn test_less_than_works_when_position_b_more_then_a() {
	earlier_position := Position{
		line:   2
		offset: 20
	}
	later_position := Position{
		line:   3
		offset: 10
	}

	assert later_position < earlier_position == false
}

fn test_more_than_works_when_position_b_more_then_a() {
	earlier_position := Position{
		line:   2
		offset: 20
	}
	later_position := Position{
		line:   3
		offset: 10
	}

	assert later_position > earlier_position
}

fn test_more_than_works_when_position_a_less_then_b() {
	earlier_position := Position{
		line:   2
		offset: 20
	}
	later_position := Position{
		line:   3
		offset: 10
	}

	assert earlier_position > later_position == false
}

fn test_compare_works_when_lines_and_offsets_are_equal() {
	position_a := Position{
		line:   11
		offset: 3
	}
	position_b := Position{
		line:   11
		offset: 3
	}

	assert position_a <= position_b
	assert position_a >= position_b
	assert position_a == position_b
}

fn test_compare_works_when_lines_and_offsets_are_not_equal() {
	position_a := Position{
		line:   11
		offset: 3
	}
	position_b := Position{
		line:   8
		offset: 3
	}

	assert position_a != position_b
}
