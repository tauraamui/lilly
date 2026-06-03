module line

fn test_line_buffer_delta_following_gap() {
	mut lb := Buffer.new()
	lb.apply_delta(5)
	lb.insert_after_current(5)
	lb.apply_delta(5)
	lb.insert_after_current(10)
	lb.apply_delta(5)
	lb.insert_after_current(15)

	lb.move_current_line_up()
	lb.move_current_line_up()
	lb.apply_delta(2)
	assert lb.offset_at(2) == u64(12)
	assert lb.offset_at(3) == u64(17)

	lb.move_current_line_down()
	assert lb.offset_at(2) == u64(12)
	assert lb.offset_at(3) == u64(17)

	lb.move_current_line_down()
	assert lb.offset_at(3) == u64(17)

	lb.move_current_line_up()
	lb.move_current_line_up()
	lb.apply_delta(-3)
	assert lb.offset_at(2) == u64(9)
	assert lb.offset_at(3) == u64(14)

	lb.move_current_line_down()
	assert lb.offset_at(2) == u64(9)
	assert lb.offset_at(3) == u64(14)

	lb.move_current_line_down()
	assert lb.offset_at(3) == u64(14)
}

fn test_line_buffer_line_removal() {
	mut lb := Buffer.new()
	lb.apply_delta(5)
	lb.insert_after_current(5)
	lb.apply_delta(5)
	lb.insert_after_current(10)

	lb.move_current_line_up()
	lb.apply_delta(-2)
	lb.remove_line_after_current()
	assert lb.len() == 2
	assert lb.offset_at(0) == u64(0)
	assert lb.offset_at(1) == u64(5)

	lb.remove_current_line()
	assert lb.len() == 1
	assert lb.current_line == 0
	assert lb.offset_at(0) == u64(0)
}
