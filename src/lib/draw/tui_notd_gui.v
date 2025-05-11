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

// IMPORTANT AMENDMENT NOTICE: Some code within this file is under the MIT license.
// All instances of these pieces of code are clearly marked and noted.

module draw

import term.ui as tui
import strings

struct Pos {
mut:
	x int
	y int
}

struct Grid {
mut:
	data      []Cell
	prev_data []Cell
	width     int
	height    int
}

fn Grid.new(width int, height int) !Grid {
	if width < 0 || height < 0 { return error("width and height must be positive") }
	mut grid_data := []Cell{ len: width * height }
	for i in 0..grid_data.len {
		grid_data[i] = Cell{}
	}
	return Grid{ width: width, height: height, data: grid_data }
}

fn (mut grid Grid) set(x int, y int, c Cell) ! {
	if x < 0 || x >= grid.width || y < 0 || y >= grid.height {
		return error("x: ${x}, y: ${y} is out of bounds")
	}
	index := y * grid.width + x
	if index >= grid.data.len { return }
	grid.data[index] = c
}

fn (grid Grid) get(x int, y int) !Cell {
	if x < 0 || x >= grid.width || y < 0 || y >= grid.height {
		return error("x: ${x}, y: ${y} is out of bounds")
	}
	index := y * grid.width + x
	return grid.data[index]
}

fn (grid Grid) get_rows(min int, max int) ![][]Cell {
	if min < 0 || min >= grid.data.len || max < 0 || max >= grid.data.len || min > max {
		return error("invalid row range")
	}
	rows_in_range := max - min + 1
	mut result := [][]Cell{ len: rows_in_range }

	for i in 0..rows_in_range {
		current_row := min + i
		start_index := current_row * grid.width
		end_index := start_index + grid.width
		result[i] = grid.data[start_index..end_index]
	}

	return result
}

fn (mut grid Grid) resize(width int, height int) ! {
	if width <= 0 || height <= 0 { return error("width and height must be positive") }
	if height == grid.height && width == grid.width {
		return
	}

	mut new_data := []Cell{ len: width * height }
	for i in 0..new_data.len {
		new_data[i] = Cell{}
	}
	overlap_rows := int_min(grid.height, height)
	overlap_cols := int_min(grid.width, width)

	for i in 0..overlap_rows {
		for j in 0..overlap_cols {
			old_index := i * grid.width + j
			new_index := i * width + j
			if old_index >= grid.data.len { continue }
			new_data[new_index] = grid.data[old_index]
		}
	}

	grid.width = width
	grid.height = height
	grid.data = new_data
}

pub enum Style as u8 {
	strikethrough
}

struct Cell {
	data         ?rune
	visual_width int // account for runes which are unicode chars (multiple width chars)
	fg_color     ?Color
	bg_color     ?Color
	style        ?Style
}

fn (cell Cell) str() string {
	r := cell.data or { return [` `].string() }
	return [r].string()
}

enum CursorStyle as u8 {
	block
	underline
	vertical_bar
}

struct Context {
	render_debug bool
mut:
	ref            &tui.Context
	data           Grid
	prev_data      ?Grid
	cursor_pos     Pos
	cursor_pos_set bool
	cursor_style   CursorStyle
	hide_cursor    bool
	style          ?Style
	bold           bool
	fg_color       ?Color
	bg_color       ?Color
}

type Runner = fn () !

pub fn new_context(cfg Config) (&Contextable, Runner) {
	mut ctx := Context{
		render_debug: cfg.render_debug
		ref: tui.init(
			user_data: cfg.user_data
			event_fn:  fn [cfg] (e &tui.Event, app voidptr) {
				cfg.event_fn(Event{e}, app)
			}
			frame_fn:             cfg.frame_fn
			capture_events:       cfg.capture_events
			use_alternate_buffer: cfg.use_alternate_buffer
			frame_rate: 30
		)
	}
	ctx.setup_grid() or { panic("unable to init grid -> ${err}") }
	return ctx, unsafe { ctx.run }
}

fn (mut ctx Context) setup_grid() ! {
	ctx.data = Grid.new(ctx.window_width(), ctx.window_height())!
}

fn (mut ctx Context) rate_limit_draws() bool {
	return true
}

fn (mut ctx Context) render_debug() bool { return ctx.render_debug }

fn (mut ctx Context) window_width() int {
	if ctx.ref == unsafe { nil } { return 100 }
	return ctx.ref.window_width
}

fn (mut ctx Context) window_height() int {
	if ctx.ref == unsafe { nil } { return 100 }
	return ctx.ref.window_height
}

fn (mut ctx Context) write(c string) {
	cursor_pos := ctx.cursor_pos
	for i, c_char in c.runes() {
		ctx.data.set(
			cursor_pos.x + i, cursor_pos.y,
			Cell{ data: c_char, fg_color: ctx.fg_color, bg_color: ctx.bg_color, style: ctx.style }
		) or { break }
	}
}

fn (mut ctx Context) bold() {
	ctx.bold = true
}

fn (mut ctx Context) set_style(s Style) {
	ctx.style = s
}

fn (mut ctx Context) clear_style() {
	ctx.style = none
}

fn (mut ctx Context) set_cursor_position(x int, y int) {
	ctx.cursor_pos = Pos{ x: x, y: y }
	ctx.cursor_pos_set = true
}

fn (mut ctx Context) set_cursor_to_block() {
	ctx.cursor_style = .block
}

fn (mut ctx Context) set_cursor_to_underline() {
	ctx.cursor_style = .underline
}

fn (mut ctx Context) set_cursor_to_vertical_bar() {
	ctx.cursor_style = .vertical_bar
}

fn (mut ctx Context) show_cursor() {
	ctx.hide_cursor = false
}

fn (mut ctx Context) hide_cursor() {
	ctx.hide_cursor = true
}

fn (mut ctx Context) set_color(c Color) {
	ctx.fg_color = c
}

fn (mut ctx Context) set_bg_color(c Color) {
	ctx.bg_color = c
}

fn (mut ctx Context) reset_color() {
	ctx.fg_color = none
}

fn (mut ctx Context) reset_bg_color() {
	ctx.bg_color = none
}

fn (mut ctx Context) reset() {
	ctx.bold     = false
	ctx.fg_color = none
	ctx.bg_color = none
}

fn (mut ctx Context) clear() {
	mut new_data := []Cell{ len: ctx.window_width() * ctx.window_height() }
	for i in 0..new_data.len {
		new_data[i] = Cell{}
	}
	ctx.data.data = new_data
}

fn (mut ctx Context) draw_point(x int, y int) {
	ctx.set_cursor_position(x, y)
	ctx.write(' ')
}

fn (mut ctx Context) draw_text(x int, y int, text string) {
	ctx.set_cursor_position(x, y)
	ctx.write(text)
}

fn (mut ctx Context) draw_line(x int, y int, x2 int, y2 int) {
	// **** CODE BELOW is MIT LICENSED ****
	// see https://github.com/vlang/v/blob/9dc69ef2aad8c8991fa740d10087ff36ffc58279/vlib/term/ui/ui.c.v#L139
	// ===== BLOCK START =====
	min_x, min_y := if x < x2 { x } else { x2 }, if y < y2 { y } else { y2 }
	max_x, _ := if x > x2 { x } else { x2 }, if y > y2 { y } else { y2 }
	if y == y2 {
		// Horizontal line, performance improvement
		ctx.set_cursor_position(min_x, min_y)
		ctx.write(strings.repeat(` `, max_x + 1 - min_x))
		return
	}
	// Draw the various points with Bresenham's line algorithm:
	mut x0, x1 := x, x2
	mut y0, y1 := y, y2
	sx := if x0 < x1 { 1 } else { -1 }
	sy := if y0 < y1 { 1 } else { -1 }
	dx := if x0 < x1 { x1 - x0 } else { x0 - x1 }
	dy := if y0 < y1 { y0 - y1 } else { y1 - y0 } // reversed
	mut err := dx + dy
	for {
		// res << Segment{ x0, y0 }
		ctx.draw_point(x0, y0)
		if x0 == x1 && y0 == y1 {
			break
		}
		e2 := 2 * err
		if e2 >= dy {
			err += dy
			x0 += sx
		}
		if e2 <= dx {
			err += dx
			y0 += sy
		}
	}
	// ===== BLOCK END =====
}

fn (mut ctx Context) draw_dashed_line(x int, y int, x2 int, y2 int) {
	// **** CODE BELOW is MIT LICENSED ****
	// see https://github.com/vlang/v/blob/9dc69ef2aad8c8991fa740d10087ff36ffc58279/vlib/term/ui/ui.c.v#L175
	// ===== BLOCK START =====
	// Draw the various points with Bresenham's line algorithm:
	mut x0, x1 := x, x2
	mut y0, y1 := y, y2
	sx := if x0 < x1 { 1 } else { -1 }
	sy := if y0 < y1 { 1 } else { -1 }
	dx := if x0 < x1 { x1 - x0 } else { x0 - x1 }
	dy := if y0 < y1 { y0 - y1 } else { y1 - y0 } // reversed
	mut err := dx + dy
	mut i := 0
	for {
		if i % 2 == 0 {
			ctx.draw_point(x0, y0)
		}
		if x0 == x1 && y0 == y1 {
			break
		}
		e2 := 2 * err
		if e2 >= dy {
			err += dy
			x0 += sx
		}
		if e2 <= dx {
			err += dx
			y0 += sy
		}
		i++
	}
	// ===== BLOCK END =====
}

fn (mut ctx Context) draw_rect(x int, y int, width int, height int) {
	x2 := x + (width - 1)
	y2 := y + (height - 1)
	// **** CODE BELOW is MIT LICENSED ****
	// see https://github.com/vlang/v/blob/9dc69ef2aad8c8991fa740d10087ff36ffc58279/vlib/term/ui/ui.c.v#L206
	// ===== BLOCK START =====
	if y == y2 || x == x2 {
		ctx.draw_line(x, y, x2, y2)
		return
	}
	min_y, max_y := if y < y2 { y, y2 } else { y2, y }
	for y_pos in min_y .. max_y + 1 {
		ctx.draw_line(x, y_pos, x2, y_pos)
	}
	// ===== BLOCK END =====
}

fn (mut ctx Context) run() ! {
	return ctx.ref.run()
}

fn (mut ctx Context) flush() {
	defer { ctx.prev_data = ctx.data }

	ctx.data.resize(ctx.window_width(), ctx.window_height()) or { panic("flush failed to resize grid -> ${err}") }
	ctx.ref.hide_cursor()
	for y in 0..ctx.data.height {
		for x in 0..ctx.data.width {
			cell := ctx.data.get(x, y) or { Cell{} }
			if prev_grid := ctx.prev_data {
				if prev_cell := prev_grid.get(x, y) {
					if prev_cell == cell { continue }
				}
			}
			ctx.ref.set_cursor_position(x + 1, y + 1)
			if c := cell.fg_color { ctx.ref.set_color(tui.Color{ c.r, c.g, c.b }) }
			if c := cell.bg_color { ctx.ref.set_bg_color(tui.Color{ c.r, c.g, c.b }) }
			ctx.ref.write(cell.str())

			ctx.ref.reset_bg_color()
			ctx.ref.reset_color()
		}
	}
	ctx.ref.set_cursor_position(ctx.cursor_pos.x, ctx.cursor_pos.y)
	if ctx.hide_cursor == false {
		ctx.ref.show_cursor()
		match ctx.cursor_style {
			.underline { ctx.ref.write('\x1b[4 q') }
			.vertical_bar { ctx.ref.write('\x1b[6 q') }
			else {
				ctx.ref.write('\x1b[0 q')
			}
		}
	}
	ctx.ref.flush()
}

