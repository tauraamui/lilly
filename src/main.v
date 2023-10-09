module main

import term.ui as tui
import log

struct App {
mut:
	log       &log.Log
    tui       &tui.Context = unsafe { nil }
	view      &View = unsafe { nil }
	views     []View
	cur_split int
	words     []string
	changed   bool
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
	match e.typ {
		.key_down {
			app.changed = true
			mut view := app.view
			view.on_key_down(e)
		}
		.resized {
			app.changed = true
		}
		else {}
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
	if app.changed {
		app.changed = false
		app.tui.clear()

		mut view := app.view
		view.draw(mut app.tui)
		app.tui.set_cursor_position(0, 0)

		app.tui.flush()
	}
}

[console]
fn main() {
	mut l := log.Log{}
	l.set_level(.debug)
	l.set_full_logpath("./debug.log")
	defer {
		l.flush()
		l.close()
	}

    mut app := &App{
		log: &l
		changed: true
	}

    app.tui = tui.init(
        user_data: app
        event_fn: event
        frame_fn: frame
        hide_cursor: true
		capture_events: true
		use_alternate_buffer: true
    )
	app.views << app.new_view()
	app.update_view()

	app.view.open_file("./src/main.v")

    app.tui.run()!
}
