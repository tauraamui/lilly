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

fn test_immediate_context_draw_text_sets_cells() {
	mut ctx := ImmediateContext{
		ref: unsafe { nil }
	}
	ctx.setup_grid()!

	ctx.draw_text(10, 10, "This is a")
	assert ctx.data.get(9, 10)!  == Cell{ data: none }
	assert ctx.data.get(10, 10)! == Cell{ data: rune(`T`) }
	assert ctx.data.get(11, 10)! == Cell{ data: rune(`h`) }
	assert ctx.data.get(12, 10)! == Cell{ data: rune(`i`) }
	assert ctx.data.get(13, 10)! == Cell{ data: rune(`s`) }
	assert ctx.data.get(14, 10)! == Cell{ data: rune(` `) }
	assert ctx.data.get(15, 10)! == Cell{ data: rune(`i`) }
	assert ctx.data.get(16, 10)! == Cell{ data: rune(`s`) }
	assert ctx.data.get(17, 10)! == Cell{ data: rune(` `) }
	assert ctx.data.get(18, 10)! == Cell{ data: rune(`a`) }
	assert ctx.data.get(19, 10)! == Cell{ data: none }
}

