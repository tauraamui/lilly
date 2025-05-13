// Copyright 2025 The Lilly Edtior contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

module draw

import term.ui as tui
import lib.utf8

fn test_cell_data_to_string() {
	cell := Cell{ data: none }
	assert cell.str() == " "
}

fn test_cell_data_single_rune_to_string() {
	cell := Cell{ data: rune(`x`) }
	assert cell.str() == "x"
}

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

struct MockNativeContext {
	window_width  int
	window_height int
mut:
	on_hide_cursor_cb fn ()
	on_write_cb       fn (s string)
}

fn (mocknctx MockNativeContext) set_cursor_position(x int, y int) {}

fn (mocknctx MockNativeContext) show_cursor() {}

fn (mocknctx MockNativeContext) hide_cursor() {
	if mocknctx.on_hide_cursor_cb == unsafe { nil } { return }
	mocknctx.on_hide_cursor_cb()
}

fn (mocknctx MockNativeContext) set_color(c tui.Color) {}

fn (mocknctx MockNativeContext) set_bg_color(c tui.Color) {}

fn (mocknctx MockNativeContext) reset_color() {}

fn (mocknctx MockNativeContext) reset_bg_color() {}

fn (mocknctx MockNativeContext) write(c string) {
	if mocknctx.on_write_cb == unsafe { nil } { return }
	mocknctx.on_write_cb(c)
}

fn (mocknctx MockNativeContext) flush() {}

fn (mocknctx MockNativeContext) run() ! {
	return error("unable to run mock native context")
}

fn test_context_write_to_native_context() {
	mut cursor_hidden := false
	mut cursor_hidden_ref := &cursor_hidden

	mut drawn_text := []string{}
	mut drawn_text_ref := &drawn_text

	mut native := MockNativeContext{
		window_width: 20,
		window_height: 1,
		on_hide_cursor_cb: fn [mut cursor_hidden_ref] () {
			unsafe { *cursor_hidden_ref = true }
		}
		on_write_cb: fn [mut drawn_text_ref] (c string) {
			drawn_text_ref << c
		}
	}
	mut ctx := Context{
		ref: native
	}
	ctx.setup_grid()!

	ctx.draw_text(0, 0, "This is a sentence")
	ctx.flush()

	assert cursor_hidden
	assert drawn_text[..drawn_text.len - 1] == ["T", "h", "i", "s", " ", "i", "s", " ", "a", " ", "s", "e", "n", "t", "e", "n", "c", "e", " ", " "]
}

fn test_context_write_to_native_context_with_double_width_char() {
	mut cursor_hidden := false
	mut cursor_hidden_ref := &cursor_hidden

	mut drawn_text := []string{}
	mut drawn_text_ref := &drawn_text

	mut native := MockNativeContext{
		window_width: 20,
		window_height: 1,
		on_hide_cursor_cb: fn [mut cursor_hidden_ref] () {
			unsafe { *cursor_hidden_ref = true }
		}
		on_write_cb: fn [mut drawn_text_ref] (c string) {
			drawn_text_ref << c
		}
	}
	mut ctx := Context{
		ref: native
	}
	ctx.setup_grid()!

	ctx.draw_text(0, 0, "This is a ${utf8.emoji_shark_char} in my sentence")
	ctx.flush()

	assert cursor_hidden
	assert drawn_text[..drawn_text.len - 1] == ["T", "h", "i", "s", " ", "i", "s", " ", "a", " ", "${utf8.emoji_shark_char}", " ", "i", "n", " ", "m", "y", " ", "s", "e"]
}

fn test_context_draw_text_sets_cells() {
	mut ctx := Context{
		ref: unsafe { nil }
	}
	ctx.setup_grid()!

	ctx.draw_text(10, 10, "This is a line of text")
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
	assert ctx.data.get(19, 10)! == Cell{ data: rune(` `) }
	assert ctx.data.get(20, 10)! == Cell{ data: rune(`l`) }
	assert ctx.data.get(21, 10)! == Cell{ data: rune(`i`) }
	assert ctx.data.get(22, 10)! == Cell{ data: rune(`n`) }
	assert ctx.data.get(23, 10)! == Cell{ data: rune(`e`) }
	assert ctx.data.get(24, 10)! == Cell{ data: rune(` `) }
	assert ctx.data.get(25, 10)! == Cell{ data: rune(`o`) }
	assert ctx.data.get(26, 10)! == Cell{ data: rune(`f`) }
	assert ctx.data.get(27, 10)! == Cell{ data: rune(` `) }
	assert ctx.data.get(28, 10)! == Cell{ data: rune(`t`) }
	assert ctx.data.get(29, 10)! == Cell{ data: rune(`e`) }
	assert ctx.data.get(30, 10)! == Cell{ data: rune(`x`) }
	assert ctx.data.get(31, 10)! == Cell{ data: rune(`t`) }
	assert ctx.data.get(32, 10)! == Cell{ data: none }
}

fn test_context_draw_text_sets_cells_get_rows() {
	mut ctx := Context{
		ref: unsafe { nil }
	}
	ctx.setup_grid()!

	ctx.draw_text(10, 10, "This is a line of text")
	cells := ctx.data.get_rows(10, 10)!
	assert cells[0][9] == Cell{ data: none }
	assert cells[0][10..32] == [
		Cell{ data: rune(`T`) }, Cell{ data: rune(`h`) }, Cell{ data: rune(`i`) }, Cell{ data: rune(`s`) },
		Cell{ data: rune(` `) },
		Cell{ data: rune(`i`) }, Cell{ data: rune(`s`) },
		Cell{ data: rune(` `) },
		Cell{ data: rune(`a`) },
		Cell{ data: rune(` `) },
		Cell{ data: rune(`l`) }, Cell{ data: rune(`i`) }, Cell{ data: rune(`n`) }, Cell{ data: rune(`e`) },
		Cell{ data: rune(` `) },
		Cell{ data: rune(`o`) }, Cell{ data: rune(`f`) },
		Cell{ data: rune(` `) },
		Cell{ data: rune(`t`) }, Cell{ data: rune(`e`) }, Cell{ data: rune(`x`) }, Cell{ data: rune(`t`) },
	]
	assert cells[0][33] == Cell{ data: none }
}

fn test_context_draw_text_with_fg_color_set_in_segments() {
	mut ctx := Context{
		ref: unsafe { nil }
	}
	ctx.setup_grid()!

	ctx.set_color(Color{ r: 100, g: 20, b: 190 })
	ctx.draw_text(0, 0, "Some blue text")
	ctx.set_color(Color{ r: 60, g: 133, b: 20 })
	ctx.draw_text(14, 0, " random ")
	ctx.reset_color()
	ctx.draw_text(22, 0, "normal uncoloured text")

	cells := ctx.data.get_rows(0, 0)!
	assert cells[0][0] == Cell{ data: rune(`S`), fg_color: Color{ r: 100, g: 20, b: 190 } }
	assert cells[0][1] == Cell{ data: rune(`o`), fg_color: Color{ r: 100, g: 20, b: 190 } }
	assert cells[0][2] == Cell{ data: rune(`m`), fg_color: Color{ r: 100, g: 20, b: 190 } }
	assert cells[0][3] == Cell{ data: rune(`e`), fg_color: Color{ r: 100, g: 20, b: 190 } }
	assert cells[0][4] == Cell{ data: rune(` `), fg_color: Color{ r: 100, g: 20, b: 190 } }

	assert cells[0][5] == Cell{ data: rune(`b`), fg_color: Color{ r: 100, g: 20, b: 190 } }
	assert cells[0][6] == Cell{ data: rune(`l`), fg_color: Color{ r: 100, g: 20, b: 190 } }
	assert cells[0][7] == Cell{ data: rune(`u`), fg_color: Color{ r: 100, g: 20, b: 190 } }
	assert cells[0][8] == Cell{ data: rune(`e`), fg_color: Color{ r: 100, g: 20, b: 190 } }
	assert cells[0][9] == Cell{ data: rune(` `), fg_color: Color{ r: 100, g: 20, b: 190 } }

	assert cells[0][10] == Cell{ data: rune(`t`), fg_color: Color{ r: 100, g: 20, b: 190 } }
	assert cells[0][11] == Cell{ data: rune(`e`), fg_color: Color{ r: 100, g: 20, b: 190 } }
	assert cells[0][12] == Cell{ data: rune(`x`), fg_color: Color{ r: 100, g: 20, b: 190 } }
	assert cells[0][13] == Cell{ data: rune(`t`), fg_color: Color{ r: 100, g: 20, b: 190 } }
	assert cells[0][14] == Cell{ data: rune(` `), fg_color: Color{ r: 60, g: 133, b: 20 } }

	assert cells[0][15] == Cell{ data: rune(`r`), fg_color: Color{ r: 60, g: 133, b: 20 } }
	assert cells[0][16] == Cell{ data: rune(`a`), fg_color: Color{ r: 60, g: 133, b: 20 } }
	assert cells[0][17] == Cell{ data: rune(`n`), fg_color: Color{ r: 60, g: 133, b: 20 } }
	assert cells[0][18] == Cell{ data: rune(`d`), fg_color: Color{ r: 60, g: 133, b: 20 } }
	assert cells[0][19] == Cell{ data: rune(`o`), fg_color: Color{ r: 60, g: 133, b: 20 } }
	assert cells[0][20] == Cell{ data: rune(`m`), fg_color: Color{ r: 60, g: 133, b: 20 } }
	assert cells[0][21] == Cell{ data: rune(` `), fg_color: Color{ r: 60, g: 133, b: 20 } }

	assert cells[0][22] == Cell{ data: rune(`n`), fg_color: none }
	assert cells[0][23] == Cell{ data: rune(`o`), fg_color: none }
	assert cells[0][24] == Cell{ data: rune(`r`), fg_color: none }
	assert cells[0][25] == Cell{ data: rune(`m`), fg_color: none }
	assert cells[0][26] == Cell{ data: rune(`a`), fg_color: none }
	assert cells[0][27] == Cell{ data: rune(`l`), fg_color: none }
	assert cells[0][28] == Cell{ data: rune(` `), fg_color: none }

	assert cells[0][29] == Cell{ data: rune(`u`), fg_color: none }
	assert cells[0][30] == Cell{ data: rune(`n`), fg_color: none }
	assert cells[0][31] == Cell{ data: rune(`c`), fg_color: none }
	assert cells[0][32] == Cell{ data: rune(`o`), fg_color: none }
	assert cells[0][33] == Cell{ data: rune(`l`), fg_color: none }
	assert cells[0][34] == Cell{ data: rune(`o`), fg_color: none }
	assert cells[0][35] == Cell{ data: rune(`u`), fg_color: none }
	assert cells[0][36] == Cell{ data: rune(`r`), fg_color: none }
	assert cells[0][37] == Cell{ data: rune(`e`), fg_color: none }
	assert cells[0][38] == Cell{ data: rune(`d`), fg_color: none }
}

fn test_context_draw_rect_sets_grid_cells() {
	mut ctx := Context{
		ref: unsafe { nil }
	}
	ctx.setup_grid()!

	ctx.draw_rect(3, 1, 5, 10)

	rows := ctx.data.get_rows(0, 11)!
	assert rows[0][2..9] == [Cell{ data: none }, Cell{ data: none }, Cell{ data: none }, Cell{ data: none }, Cell{ data: none }, Cell{ data: none }, Cell{ data: none }]
	assert rows[1][2..9] == [Cell{ data: none }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: none }]
	assert rows[2][2..9] == [Cell{ data: none }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: none }]
	assert rows[3][2..9] == [Cell{ data: none }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: none }]
	assert rows[4][2..9] == [Cell{ data: none }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: none }]
	assert rows[5][2..9] == [Cell{ data: none }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: none }]
	assert rows[6][2..9] == [Cell{ data: none }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: none }]
	assert rows[7][2..9] == [Cell{ data: none }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: none }]
	assert rows[8][2..9] == [Cell{ data: none }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: none }]
	assert rows[9][2..9] == [Cell{ data: none }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: none }]
	assert rows[10][2..9] == [Cell{ data: none }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: rune(` `) }, Cell{ data: none }]
	assert rows[11][2..9] == [Cell{ data: none }, Cell{ data: none }, Cell{ data: none }, Cell{ data: none }, Cell{ data: none }, Cell{ data: none }, Cell{ data: none }]
}

fn test_context_multiple_draw_text_sets_cells_overwrites() {
	mut ctx := Context{
		ref: unsafe { nil }
	}
	ctx.setup_grid()!

	ctx.draw_text(10, 10, "This is a line of text")
	ctx.draw_text(10, 10, "Also some other stuff!")
	assert ctx.data.get(9, 10)!  == Cell{ data: none }
	assert ctx.data.get(10, 10)! == Cell{ data: rune(`A`) }
	assert ctx.data.get(11, 10)! == Cell{ data: rune(`l`) }
	assert ctx.data.get(12, 10)! == Cell{ data: rune(`s`) }
	assert ctx.data.get(13, 10)! == Cell{ data: rune(`o`) }
	assert ctx.data.get(14, 10)! == Cell{ data: rune(` `) }
	assert ctx.data.get(15, 10)! == Cell{ data: rune(`s`) }
	assert ctx.data.get(16, 10)! == Cell{ data: rune(`o`) }
	assert ctx.data.get(17, 10)! == Cell{ data: rune(`m`) }
	assert ctx.data.get(18, 10)! == Cell{ data: rune(`e`) }
	assert ctx.data.get(19, 10)! == Cell{ data: rune(` `) }
	assert ctx.data.get(20, 10)! == Cell{ data: rune(`o`) }
	assert ctx.data.get(21, 10)! == Cell{ data: rune(`t`) }
	assert ctx.data.get(22, 10)! == Cell{ data: rune(`h`) }
	assert ctx.data.get(23, 10)! == Cell{ data: rune(`e`) }
	assert ctx.data.get(24, 10)! == Cell{ data: rune(`r`) }
	assert ctx.data.get(25, 10)! == Cell{ data: rune(` `) }
	assert ctx.data.get(26, 10)! == Cell{ data: rune(`s`) }
	assert ctx.data.get(27, 10)! == Cell{ data: rune(`t`) }
	assert ctx.data.get(28, 10)! == Cell{ data: rune(`u`) }
	assert ctx.data.get(29, 10)! == Cell{ data: rune(`f`) }
	assert ctx.data.get(30, 10)! == Cell{ data: rune(`f`) }
	assert ctx.data.get(31, 10)! == Cell{ data: rune(`!`) }
	assert ctx.data.get(32, 10)! == Cell{ data: none }
}

fn test_context_multiple_draw_text_sets_cells_overwrites_only_cells_that_overlap() {
	mut ctx := Context{
		ref: unsafe { nil }
	}
	ctx.setup_grid()!

	ctx.draw_text(10, 10, "This is a line of text")
	ctx.draw_text(10, 10, "Not as much")
	assert ctx.data.get(9, 10)!  == Cell{ data: none }
	assert ctx.data.get(10, 10)! == Cell{ data: rune(`N`) }
	assert ctx.data.get(11, 10)! == Cell{ data: rune(`o`) }
	assert ctx.data.get(12, 10)! == Cell{ data: rune(`t`) }
	assert ctx.data.get(13, 10)! == Cell{ data: rune(` `) }
	assert ctx.data.get(14, 10)! == Cell{ data: rune(`a`) }
	assert ctx.data.get(15, 10)! == Cell{ data: rune(`s`) }
	assert ctx.data.get(16, 10)! == Cell{ data: rune(` `) }
	assert ctx.data.get(17, 10)! == Cell{ data: rune(`m`) }
	assert ctx.data.get(18, 10)! == Cell{ data: rune(`u`) }
	assert ctx.data.get(19, 10)! == Cell{ data: rune(`c`) }
	assert ctx.data.get(20, 10)! == Cell{ data: rune(`h`) }
	assert ctx.data.get(21, 10)! == Cell{ data: rune(`i`) }
	assert ctx.data.get(22, 10)! == Cell{ data: rune(`n`) }
	assert ctx.data.get(23, 10)! == Cell{ data: rune(`e`) }
	assert ctx.data.get(24, 10)! == Cell{ data: rune(` `) }
	assert ctx.data.get(25, 10)! == Cell{ data: rune(`o`) }
	assert ctx.data.get(26, 10)! == Cell{ data: rune(`f`) }
	assert ctx.data.get(27, 10)! == Cell{ data: rune(` `) }
	assert ctx.data.get(28, 10)! == Cell{ data: rune(`t`) }
	assert ctx.data.get(29, 10)! == Cell{ data: rune(`e`) }
	assert ctx.data.get(30, 10)! == Cell{ data: rune(`x`) }
	assert ctx.data.get(31, 10)! == Cell{ data: rune(`t`) }
	assert ctx.data.get(32, 10)! == Cell{ data: none }
}

