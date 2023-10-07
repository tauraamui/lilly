module main

import term.ui as tui

enum Mode as u8 {
	normal
	visual
	insert
}

struct App {
mut:
    tui       &tui.Context = unsafe { nil }
	mode      Mode
	view      &View = unsafe { nil }
	views     []View
	cur_split int
	words     []string
}

fn (mut app App) update_view() {
	$if debug {
		println('update view len=${app.views.len}')
	}
	unsafe {
		app.view = &app.views[app.cur_split]
	}
}


fn event(e &tui.Event, mut app &App) {
    if e.typ == .key_down {
		mut view := app.view
		view.on_key_down(e)
    }

	/*
	if e.typ == .key_down {
		match e.code {
			.j { app.cursor.pos.y += 1 }
			.k { app.cursor.pos.y -= 1; if app.cursor.pos.y < 1 { app.cursor.pos.y = 1 } }
			else {}
		}
	}
	*/
}

fn frame(mut app &App) {
    app.tui.clear()

	mut view := app.view
	view.draw(mut app.tui)

    app.tui.reset()
    app.tui.flush()
}

[console]
fn main() {
    mut app := &App{
		mode: .normal
	}
    app.tui = tui.init(
        user_data: app
        event_fn: event
        frame_fn: frame
        hide_cursor: true
		capture_events: true
    )
	app.views << app.new_view()
	app.update_view()

	app.view.open_file("./src/main.v")

    app.tui.run()!
}
