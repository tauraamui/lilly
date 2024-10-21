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
import lib.clipboardv2
import lib.draw
import os.cmdline
import strings

const gitcommit_hash = $embed_file('./src/.githash').to_string()

struct App {
mut:
	log       &log.Log
	ui        &draw.Contextable = unsafe { nil }
	editor    &Editor           = unsafe { nil }
	view      &View             = unsafe { nil }
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

fn event(e draw.Event, mut app App) {
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

fn frame(mut app App) {
	if app.ui.rate_limit_draws() && !app.changed {
		return
	}
	app.changed = false
	app.ui.clear()

	app.editor.draw(mut app.ui)

	app.ui.flush()
}

struct Options {
mut:
	log_level                        log.Level
	long_show_version_flag           string
	short_show_version_flag          string
	show_version                     bool
	long_show_help_flag              string
	short_show_help_flag             string
	show_help                        bool
	long_debug_mode_flag             string
	short_debug_mode_flag            string
	debug_mode                       bool
	long_render_debug_mode_flag      string
	short_render_debug_mode_flag     string
	render_debug_mode                bool
	long_capture_panics_flag         string
	short_capture_panics_flag        string
	capture_panics                   bool
	long_disable_panic_capture_flag  string
	short_disable_panic_capture_flag string
	long_log_level_label_flag        string
	short_log_level_label_flag       string
	disable_panic_capture            bool
}

fn resolve_options_from_args(args []string) Options {
	flags := cmdline.only_options(args)
	mut opts := Options{
		long_show_version_flag:           'version'
		short_show_version_flag:          'v'
		long_show_help_flag:              'help'
		short_show_help_flag:             'h'
		long_debug_mode_flag:             'debug'
		short_debug_mode_flag:            'd'
		long_render_debug_mode_flag:      'render-debug'
		short_render_debug_mode_flag:     'rd'
		long_capture_panics_flag:         'capture-panics'
		short_capture_panics_flag:        'cp'
		long_disable_panic_capture_flag:  'disable-panic-capture'
		short_disable_panic_capture_flag: 'dpc'
		long_log_level_label_flag:        'log-level'
		short_log_level_label_flag:       'll'
	}

	opts.show_version = '--${opts.long_show_version_flag}' in flags
		|| '-${opts.short_show_version_flag}' in flags
	opts.show_help = '--${opts.long_show_help_flag}' in flags
		|| '-${opts.short_show_help_flag}' in flags
	opts.debug_mode = '--${opts.long_debug_mode_flag}' in flags
		|| '-${opts.short_debug_mode_flag}' in flags
	opts.render_debug_mode = '--${opts.long_render_debug_mode_flag}' in flags
		|| '-${opts.short_render_debug_mode_flag}' in flags
	opts.capture_panics = '--${opts.long_capture_panics_flag}' in flags
		|| '-${opts.short_capture_panics_flag}' in flags
	opts.disable_panic_capture = '--${opts.long_disable_panic_capture_flag}' in flags
		|| '-${opts.short_disable_panic_capture_flag}' in flags

	opts.log_level = .disabled
	if "--${opts.long_log_level_label_flag}" in flags {
		log_level_option := cmdline.option(args, "--${opts.long_log_level_label_flag}", "").to_upper()
		opts.log_level = log.level_from_tag(log_level_option) or { log.Level.disabled }
	}

	if "-${opts.short_log_level_label_flag}" in flags {
		log_level_option := cmdline.option(args, "-${opts.short_log_level_label_flag}", "").to_upper()
		opts.log_level = log.level_from_tag(log_level_option) or { log.Level.disabled }
	}

	return opts
}

fn (opts Options) flags_str() string {
	mut sb := strings.new_builder(512)
	sb.write_string('-${opts.short_show_help_flag}, --${opts.long_show_help_flag} (show help)')
	sb.write_string('\n\t-${opts.short_show_version_flag}, --${opts.long_show_version_flag} (show version)')
	sb.write_string('\n\t-${opts.short_debug_mode_flag}, --${opts.long_debug_mode_flag} (enable debug log out)')
	sb.write_string('\n\t-${opts.short_render_debug_mode_flag}, --${opts.long_render_debug_mode_flag} (enable render debug mode)')
	sb.write_string('\n\t-${opts.short_disable_panic_capture_flag}, --${opts.long_disable_panic_capture_flag} (disable persistance of panic stack trace output)')
	sb.write_string('\n\t-${opts.short_log_level_label_flag}, --${opts.long_log_level_label_flag} [disabled | fatal | error | warn | info | debug] (set the minimum log level to output from)')
	return sb.str()
}

fn output_version_and_close(commit_hash string) {
	version_label := 'lilly - dev version (#${commit_hash})'
	print_and_exit(version_label)
}

fn output_help_and_close(opts Options) {
	msg := './lilly <option flags> <dir path/file path>\nFlags:\n\t${opts.flags_str()}'
	print_and_exit(msg)
}

type WDResolver = fn () string

fn resolve_file_and_workspace_dir_paths(args []string, resolve_wd WDResolver) !(string, string) {
	if args.len == 0 {
		return '', resolve_wd()
	}
	if args.len == 1 {
		file_or_dir_path := args[0]
		if os.is_dir(file_or_dir_path) {
			return '', file_or_dir_path
		}

		return file_or_dir_path, os.dir(file_or_dir_path)
	}
	return error('too many arguments ${args.len}, expected one')
}

fn main() {
	mut args := os.args[1..].clone()
	opts := resolve_options_from_args(args)

	// NOTE(tauraamui): I would like it to be possible to output both the
	//                  version and help simultaniously but this is low priority atm.
	// 20/Sep/2024 -> future me here, I have no idea what I was on about, like why?
	if opts.show_version {
		output_version_and_close(gitcommit_hash)
	}
	if opts.show_help {
		output_help_and_close(opts)
	}

	if opts.disable_panic_capture == false {
		persist_stderr_to_disk()
	}

	mut l := log.Log{}
	l.set_level(opts.log_level)
	if opts.log_level != .disabled {
		l.set_full_logpath('./debug.log')
		defer {
			l.flush()
			l.close()
		}
	}

	mut app := &App{
		log:     &l
		changed: true
	}

	ctx, run := draw.new_context(
		render_debug:         opts.render_debug_mode
		user_data:            app
		event_fn:             event
		frame_fn:             frame
		capture_events:       true
		use_alternate_buffer: true
	)
	app.ui = ctx

	file_path, workspace_path := resolve_file_and_workspace_dir_paths(cmdline.only_non_options(args),
		os.getwd) or {
		print_and_exit('${err}')
		'', ''
	}
	mut clip := clipboardv2.new()
	app.editor = open_editor(mut l, mut clip, gitcommit_hash, file_path, workspace_path) or {
		print_and_exit('${err}')
		unsafe { nil }
	}

	if opts.debug_mode {
		app.editor.start_debug()
	}

	run()!
}

fn print_and_exit(msg string) {
	println(msg)
	exit(1)
}
