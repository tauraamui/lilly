module main

import lib.utf8
import lib.draw
import rand

struct EmojiGrid {
mut:
	run_once bool
	width int
	height int
}

fn EmojiGrid.new() EmojiGrid {
	return EmojiGrid{
		width: 10
		height: 10
	}
}

fn (mut grid EmojiGrid) update_bounds(width int, height int) {
	if grid.width == width && grid.height == height { return }
	grid.width = width
	grid.height = height
}

fn (mut grid EmojiGrid) draw_chars(mut ctx draw.Contextable) {
	for y in 0..grid.height {
		for x in 0..grid.width {
			char_to_render := if (x == 0 || x == grid.width - 1) || (y == 0 || y == grid.height - 1) { "X" } else { "A" }
			ctx.draw_text(x + 1, y + 1, char_to_render)
		}
	}
}

fn (mut grid EmojiGrid) draw_emojis(mut ctx draw.Contextable) {
	emoji_names := utf8.emojis.keys()
	for y in 0..grid.height {
		// NOTE(tauraamui) [25/04/2025]: utf8 chars take up 2 grid cells not one
		for x in 0..(grid.width / 2) {
			emoji := utf8.emojis[emoji_names[rand.int_in_range(0, emoji_names.len) or { 0 }]]
			ctx.draw_text((x * 2) + 1, y + 1, emoji)
		}
	}
}

fn (mut grid EmojiGrid) draw(mut ctx draw.Contextable) {
	if grid.run_once { return }
	defer { grid.run_once = true }
	grid.update_bounds(ctx.window_width(), ctx.window_height())
	ctx.clear()
	// grid.draw_chars(mut ctx)
	grid.draw_emojis(mut ctx)
	ctx.flush()
}

fn (grid EmojiGrid) on_key_down(e draw.Event, mut root Root) {
	match e.code {
		.escape {
			root.quit() or { panic("failed to quit via root: ${err}") }
		}
		else {}
	}
}

interface Root {
	quit() !
}

struct App {
mut:
	ui &draw.Contextable = unsafe { nil }
	grid &EmojiGrid = unsafe { nil }
}

fn (app App) quit() ! {
	exit(0)
}

fn frame(mut app App) { app.grid.draw(mut app.ui) }
fn event(e draw.Event, mut app App) {
	match e.typ {
		.key_down {
			app.grid.on_key_down(e, mut app)
		}
		else {}
	}
}

fn main() {
	mut grid := EmojiGrid.new()
	mut app := &App{
		grid: &grid
	}

	ctx, run := draw.new_context(
		user_data: app
		event_fn: event
		frame_fn: frame
		capture_events: true
		use_alternate_buffer: true
	)
	app.ui = ctx

	run()!
}

