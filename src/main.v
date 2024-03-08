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
import log
import lib.clipboard
import lib.draw
import os.cmdline

struct App {
mut:
	log       &log.Log
	ui        &draw.Contextable = unsafe { nil }
	editor    &Editor = unsafe { nil }
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


fn event(e draw.Event, mut app &App) {
	match e.typ {
		.key_down {
			app.changed = true
			app.editor.on_key_down(e)
		}
		.resized {
			app.changed = true
		}
		else {}
	}
}

fn frame(mut app &App) {
	if app.ui.rate_limit_draws() && !app.changed { return }
	app.changed = false
	app.ui.clear()

	app.editor.draw(mut app.ui)

	app.ui.flush()
}

struct Options {
mut:
	log_level  string
	debug_mode bool
}

fn resolve_options_from_args(args []string) Options {
	flags := cmdline.only_options(args)
	return Options{
		debug_mode: "--debug" in flags || "-d" in flags
	}
}

fn main() {
	args := os.args[1..]
	opts := resolve_options_from_args(args)
	persist_stderr_to_disk()
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

	app.ui = draw.new_context(
		user_data: app
        event_fn: event
        frame_fn: frame
		capture_events: true
		use_alternate_buffer: true
	)

	files := cmdline.only_non_options(args)
	if files.len != 1 { print_and_exit("too many file paths, expected just one") }
	app.editor = open_editor(mut l, clipboard.new(), files[0]) or { print_and_exit("${err}"); unsafe { nil } }
	if opts.debug_mode {
		app.editor.start_debug()
	}

    app.ui.run()!
}

fn print_and_exit(msg string) {
	println(msg)
	exit(1)
}

