module main

import lib.utf8
import lib.draw

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

