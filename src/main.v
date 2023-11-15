// Copyright 2023 The Lilly Editor contributors
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

module main

import os
import term.ui as tui
import log
import lib.clipboard

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
		capture_events: true
		use_alternate_buffer: true
    )

	clip := clipboard.new()
	app.views << app.new_view(clip)
	app.update_view()

	path := os.args[1] or { print_and_exit("missing file path..."); "" }
	if !os.is_dir(path) { print_and_exit("given path ${path} is not a directory") }
	app.view.open_file(path)

    app.tui.run()!
}

fn print_and_exit(msg string) {
	println(msg)
	exit(1)
}

