module main

import term.ui as tui

struct Pos {
	x int
	y int
}

struct Cursor {
	pos Pos
}

struct App {
mut:
    tui    &tui.Context = unsafe { nil }
	cursor Cursor
}

fn event(e &tui.Event, mut app &App) {
    if e.typ == .key_down && e.code == .escape {
        exit(0)
    }
}

fn frame(mut app &App) {
    app.tui.clear()

    app.tui.set_bg_color(r: 53, g: 53, b: 53)
	app.tui.draw_rect(0, app.cursor.pos.y, app.tui.window_width - 1, app.cursor.pos.y)

    app.tui.reset()
    app.tui.flush()
}

fn main() {
    mut app := &App{
		cursor: Cursor{ pos: Pos{ x: 0, y: 0 } }
	}
    app.tui = tui.init(
        user_data: app
        event_fn: event
        frame_fn: frame
        hide_cursor: true
		capture_events: false
    )
    app.tui.run()!
}
