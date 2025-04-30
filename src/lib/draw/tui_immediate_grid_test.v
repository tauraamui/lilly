module draw

fn test_grid_setting_cell_reading_cell() {
	mut g := Grid.new(12, 12)
	g.set_cell(0, 0, Cell{ data: rune(`\n`) })
	assert g.get_cell(0, 0) == Cell{ data: rune(`\n`) }
}

