module main

import term.ui as tui

enum Mode as u8 {
	normal
	visual
	insert
}

struct Pos {
mut:
	x int
	y int
}

struct Cursor {
mut:
	pos Pos
}

fn (cursor Cursor) draw(mut ctx tui.Context) {
    ctx.set_bg_color(r: 53, g: 53, b: 53)
	ctx.draw_rect(0, cursor.pos.y, ctx.window_width - 1, cursor.pos.y)

}

struct App {
mut:
    tui    &tui.Context = unsafe { nil }
	mode   Mode
	cursor Cursor
}

fn event(e &tui.Event, mut app &App) {
    if e.typ == .key_down && e.code == .escape {
        exit(0)
    }

	if e.typ == .key_down {
		match e.code {
			.j { app.cursor.pos.y += 1 }
			.k { app.cursor.pos.y -= 1; if app.cursor.pos.y < 1 { app.cursor.pos.y = 1 } }
			else {}
		}
	}
}

fn frame(mut app &App) {
    app.tui.clear()

	app.cursor.draw(mut app.tui)

    app.tui.reset()
    app.tui.flush()
}

fn main() {
    mut app := &App{
		cursor: Cursor{ pos: Pos{ x: 1, y: 1 } }
		mode: .normal
	}
    app.tui = tui.init(
        user_data: app
        event_fn: event
        frame_fn: frame
        hide_cursor: true
		capture_events: true
    )
    app.tui.run()!
}
