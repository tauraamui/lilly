module buffer

fn test_new_range_returns_range() {
	assert Range.new(Position{}, Position{}) == Range{}
}

fn test_new_range_with_real_data_returns_range() {
	assert Range.new(Position{ line: 1, offset: 0 }, Position{
		line:   8
		offset: 6
	}) == Range{Position{
		line:   1
		offset: 0
	}, Position{
		line:   8
		offset: 6
	}}
}

fn test_new_range_swaps_start_and_end_when_end_precedes_start() {
	start := Position{
		line:   1
		offset: 4
	}
	end := Position{
		line:   1
		offset: 1
	}
	range := Range.new(start, end)

	assert range.start == end
	assert range.end == start
}

fn test_new_range_does_not_swap_start_and_end_if_end_does_not_precedes_start() {
	start := Position{
		line:   0
		offset: 4
	}
	end := Position{
		line:   1
		offset: 1
	}
	range := Range.new(start, end)

	assert range.start == start
	assert range.end == end
}
