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

