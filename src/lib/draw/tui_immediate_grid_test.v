module draw

fn test_grid_setting_cell_reading_cell() {
	mut g := Grid.new(12, 12)!
	g.set(0, 0, Cell{ data: rune(`\n`) })!
	assert g.get(0, 0)! == Cell{ data: rune(`\n`) }
}

fn test_grid_setting_cell_oob() {
	mut g := Grid.new(12, 12)!
	mut fail_msg := ""
	g.set(18, 0, Cell{ data: rune(`\n`) }) or { fail_msg = err.str() }
	assert fail_msg == "x: 18, y: 0 is out of bounds"
	g.get(18, 0) or { fail_msg = err.str() }
	assert fail_msg == "x: 18, y: 0 is out of bounds"
}

fn test_grid_resize_provides_ability_to_set_to_new_indexes() {
	mut g := Grid.new(12, 12)!
	g.set(0, 0, Cell{ data: rune(`\n`) })!
	assert g.get(0, 0)! == Cell{ data: rune(`\n`) }

	mut fail_msg := ""
	g.set(18, 16, Cell{ data: rune(`\n`) }) or { fail_msg = err.str() }
	assert fail_msg == "x: 18, y: 16 is out of bounds"

	fail_msg = ""
	g.resize(24, 24) or { fail_msg = err.str() }
	assert fail_msg == ""

	g.set(18, 16, Cell{ data: rune(`a`) }) or { fail_msg = err.str() }
	assert fail_msg == ""

	assert g.get(18, 16)! == Cell{ data: rune(`a`) }
}

fn test_grid_resize_shrinking_loses_data() {
	mut g := Grid.new(24, 24)!
	g.set(21, 15, Cell{ data: rune(`x`) })!
	assert g.get(21, 15)! == Cell{ data: rune(`x`) }

	mut fail_msg := ""
	g.resize(10, 10) or { fail_msg = err.str() }
	assert fail_msg == ""

	g.resize(24, 24) or { fail_msg = err.str() }
	assert fail_msg == ""

	assert g.get(21, 15)! == Cell{ data: none }
}


