module main

import lib.utf8

struct App {
	ui &draw.Contextable = unsafe { nil }
	grid &EmojiGrid = unsafe { nil }
}

struct EmojiGrid {
	width int
	height int
	data []string
}

fn EmojiGrid.new() EmojiGrid {
	return EmojiGrid{
		width: 10
		height: 10
	}
}

fn (app EmojiGrid) draw(mut ctx draw.Contextable) {
	ctx.clear()
}

fn frame(mut app App) { app.grid.draw(mut app.ui) }

fn main() {
	mut app := &App{}

	ctx, run := draw.new_context(
		user_data: app
		frame_fn: frame
		capture_events: true
		use_alternate_buffer: true
	)
	app.ui = ctx

	app.grid = EmojiGrid.new()

	run()!
}

