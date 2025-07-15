module main

import lib.utf8
import lib.draw
import rand
import strings

struct CharGrid {
mut:
	run_once bool
	width    int
	height   int
}

fn CharGrid.new() CharGrid {
	return CharGrid{
		width:  100
		height: 100
	}
}

fn (mut grid CharGrid) update_bounds(width int, height int) {
	if grid.width == width && grid.height == height {
		return
	}
	grid.width = width
	grid.height = height
}

const char_values = ['X', 'A', 'C', 'Y', 'T']

fn (mut grid CharGrid) draw_chars(mut ctx draw.Contextable) {
	for y in 0 .. grid.height {
		for x in 0 .. grid.width {
			mut index := rand.int_in_range(0, char_values.len) or { 0 }
			r := rand.int_in_range(100, 255) or { 255 }
			g := rand.int_in_range(100, 255) or { 255 }
			b := rand.int_in_range(100, 255) or { 255 }
			ctx.set_color(draw.Color{u8(r), u8(g), u8(b)})
			if (y - 4 <= 0 || y + 6 >= grid.height) || (x - 15 <= 0 || x + 15 >= grid.width) {
				index = 3
				ctx.reset_color()
			}
			mut char_to_render := char_values[index]
			if x == 0 {
				char_to_render = '${y}'
			}
			ctx.draw_text(x, y, char_to_render)
		}
	}
	ctx.set_bg_color(draw.Color{110, 150, 200})
	ctx.draw_rect(15, 10, 15, 5)
	ctx.reset_bg_color()
	ctx.set_cursor_position(1, 1)
}

fn (mut grid CharGrid) draw(mut ctx draw.Contextable) {
	ctx.hide_cursor()
	ctx.clear()
	// if grid.run_once { return }
	// defer { grid.run_once = true }
	grid.update_bounds(ctx.window_width(), ctx.window_height())
	// ctx.hide_cursor()
	grid.draw_chars(mut ctx)
	ctx.flush()
}

struct App {
mut:
	ui   &draw.Contextable = unsafe { nil }
	grid &CharGrid         = unsafe { nil }
}

fn (app App) quit() ! {
	exit(0)
}

fn frame(mut app App) {
	app.grid.draw(mut app.ui)
}

fn event(e draw.Event, mut app App) {
	match e.typ {
		.key_down {
			app.quit() or { panic(err) }
		}
		else {}
	}
}

fn main() {
	mut grid := CharGrid.new()
	mut app := &App{
		grid: &grid
	}

	ctx, run := draw.new_context(
		user_data:            app
		event_fn:             event
		frame_fn:             frame
		capture_events:       true
		use_alternate_buffer: true
	)
	app.ui = ctx

	run()!
}
