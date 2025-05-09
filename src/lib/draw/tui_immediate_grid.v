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
	if width <= 0 || height <= 0 { return error("width and height must be positive") }
	return Grid{ width: width, height: height, data: []Cell{ len: width * height } }
}

fn (mut grid Grid) set(x int, y int, c Cell) ! {
	if x < 0 || x >= grid.width || y < 0 || y >= grid.height {
		return error("x: ${x}, y: ${y} is out of bounds")
	}
	index := y * grid.width + x
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
	overlap_rows := int_min(grid.height, height)
	overlap_cols := int_min(grid.width, width)

	for i in 0..overlap_rows {
		for j in 0..overlap_cols {
			old_index := i * grid.width + j
			new_index := i * width + j
			new_data[new_index] = grid.data[old_index]
		}
	}

	grid.width = width
	grid.height = height
	grid.data = new_data
}

struct Cell {
	data         ?rune
	visual_width int // account for runes which are unicode chars (multiple width chars)
	fg_color     ?Color
	bg_color     ?Color
}

fn (cell Cell) str() string {
	r := cell.data or { return "none" }
	return r.str()
}

struct ImmediateContext {
	render_debug bool
mut:
	ref         &tui.Context
	data        Grid
	cursor_pos  Pos
	hide_cursor bool
	bold        bool
	fg_color    ?Color
	bg_color    ?Color
}

type Runner = fn () !

pub fn new_immediate_context(cfg Config) (&Contextable, Runner) {
	mut ctx := ImmediateContext{
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

fn (mut ctx ImmediateContext) setup_grid() ! {
	ctx.data = Grid.new(ctx.window_width(), ctx.window_height())!
}

fn (mut ctx ImmediateContext) rate_limit_draws() bool {
	return true
}

fn (mut ctx ImmediateContext) render_debug() bool { return ctx.render_debug }

fn (mut ctx ImmediateContext) window_width() int {
	return 100
}

fn (mut ctx ImmediateContext) window_height() int {
	return 100
}

fn (mut ctx ImmediateContext) write(c string) {
	cursor_pos := ctx.cursor_pos
	for i, c_char in c.runes() {
		ctx.data.set(
			cursor_pos.x + i, cursor_pos.y,
			Cell{ data: c_char, fg_color: ctx.fg_color, bg_color: ctx.bg_color }
		) or { break }
	}
}

fn (mut ctx ImmediateContext) bold() {
	ctx.bold = true
}

fn (mut ctx ImmediateContext) set_cursor_position(x int, y int) {
	ctx.cursor_pos = Pos{ x: x, y: y }
}

fn (mut ctx ImmediateContext) show_cursor() {
	ctx.ref.show_cursor()
	ctx.hide_cursor = false
}

fn (mut ctx ImmediateContext) hide_cursor() {
	ctx.hide_cursor = true
}

fn (mut ctx ImmediateContext) set_color(c Color) {
	ctx.fg_color = c
}

fn (mut ctx ImmediateContext) set_bg_color(c Color) {
	ctx.bg_color = c
}

fn (mut ctx ImmediateContext) reset_color() {
	ctx.fg_color = none
}

fn (mut ctx ImmediateContext) reset_bg_color() {
	ctx.bg_color = none
}

fn (mut ctx ImmediateContext) reset() {
	ctx.bold     = false
	ctx.fg_color = none
	ctx.bg_color = none
}

fn (mut ctx ImmediateContext) clear() {
	ctx.ref.clear()
}

fn (mut ctx ImmediateContext) draw_point(x int, y int) {
	ctx.set_cursor_position(x, y)
	ctx.write(' ')
}

fn (mut ctx ImmediateContext) draw_text(x int, y int, text string) {
	ctx.set_cursor_position(x, y)
	ctx.write(text)
}

fn (mut ctx ImmediateContext) draw_line(x int, y int, x2 int, y2 int) {
}

fn (mut ctx ImmediateContext) draw_rect(x int, y int, width int, height int) {
	x2 := x + (width - 1)
	y2 := y + (height - 1)
	if y == y2 || x == x2 {
		ctx.draw_line(x, y, x2, y2)
		return
	}
	min_y, max_y := if y < y2 { y, y2 } else { y2, y }
	for y_pos in min_y .. max_y + 1 {
		ctx.draw_line(x, y_pos, x2, y_pos)
	}
}

fn (mut ctx ImmediateContext) run() ! {
	return ctx.ref.run()
}

fn (mut ctx ImmediateContext) flush() {
	ctx.ref.flush()
}

