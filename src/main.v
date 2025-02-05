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
import lib.clipboardv2
import lib.draw
import lib.workspace
import os.cmdline
import strings

const gitcommit_hash = $embed_file('./src/.githash').to_string()

struct App {
mut:
	log       &log.Log
	ui        &draw.Contextable = unsafe { nil }
	lilly     &Lilly           = unsafe { nil }
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
			app.lilly.on_key_down(e)
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

	app.lilly.draw(mut app.ui)

	app.ui.flush()
}

struct Options {
mut:
	log_level                        log.Level
	long_show_help_flag              string
	short_show_help_flag             string
	show_help                        bool
	long_show_version_flag           string
	short_show_version_flag          string
	show_version                     bool
	long_show_config_path_flag        string
	short_show_config_path_flag       string
	show_config_root_path             bool
	long_symlink_flag                string
	short_symlink_flag               string
	symlink                          bool
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
	disable_panic_capture            bool
	long_log_level_label_flag        string
	short_log_level_label_flag       string
	long_gap_buffer_toggle_flag      string
	short_gap_buffer_toggle_flag     string
	use_gap_buffer                   bool
}

fn resolve_options_from_args(args []string) Options {
	flags := cmdline.only_options(args)
	mut opts := Options{
		long_show_help_flag:              'help'
		short_show_help_flag:             'h'
		long_show_version_flag:           'version'
		short_show_version_flag:          'v'
		long_show_config_path_flag:       'show-config-path'
		short_show_config_path_flag:      'scp'
		long_symlink_flag:                'symlink'
		short_symlink_flag:               'ln'
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
		long_gap_buffer_toggle_flag:      'use-gap-buffer'
		short_gap_buffer_toggle_flag:     'ugb'
	}

	opts.show_help = '--${opts.long_show_help_flag}' in flags
		|| '-${opts.short_show_help_flag}' in flags
	opts.show_version = '--${opts.long_show_version_flag}' in flags
		|| '-${opts.short_show_version_flag}' in flags
	opts.show_config_root_path = '--${opts.long_show_config_path_flag}' in flags
		|| '-${opts.short_show_config_path_flag}' in flags
	$if !windows {
		opts.symlink = '--${opts.long_symlink_flag}' in flags
			|| '-${opts.short_symlink_flag}' in flags
	}
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

	opts.use_gap_buffer = '--${opts.long_gap_buffer_toggle_flag}' in flags
		|| '-${opts.short_gap_buffer_toggle_flag}' in flags

	return opts
}

fn (opts Options) flags_str() string {
	mut sb := strings.new_builder(512)
	sb.write_string('-${opts.short_show_help_flag}, --${opts.long_show_help_flag} (show help)')
	sb.write_string('\n\t-${opts.short_show_version_flag}, --${opts.long_show_version_flag} (show version)')
	sb.write_string('\n\t-${opts.short_show_config_path_flag}, --${opts.long_show_config_path_flag} (show root config path)')
	$if !windows {
		sb.write_string('\n\t-${opts.short_symlink_flag}, --${opts.long_symlink_flag} (symlink lilly into local bin)')
	}
	sb.write_string('\n\t-${opts.short_debug_mode_flag}, --${opts.long_debug_mode_flag} (enable debug log out)')
	sb.write_string('\n\t-${opts.short_render_debug_mode_flag}, --${opts.long_render_debug_mode_flag} (enable render debug mode)')
	sb.write_string('\n\t-${opts.short_disable_panic_capture_flag}, --${opts.long_disable_panic_capture_flag} (disable persistance of panic stack trace output)')
	sb.write_string('\n\t-${opts.short_log_level_label_flag}, --${opts.long_log_level_label_flag} [disabled | fatal | error | warn | info | debug] (set the minimum log level to output from)')
	sb.write_string('\n\t-${opts.short_gap_buffer_toggle_flag}, --${opts.long_gap_buffer_toggle_flag} (enable using gap buffer)')
	return sb.str()
}

fn output_help_and_close(opts Options) {
	msg := './lilly <option flags> <dir path/file path>\nFlags:\n\t${opts.flags_str()}'
	print_and_exit(msg)
}

fn output_version_and_close(commit_hash string) {
	version_label := 'lilly - dev version (#${commit_hash})'
	print_and_exit(version_label)
}

fn output_config_root_path_and_close(config_root_path string) {
	path := os.join_path(config_root_path, workspace.lilly_config_root_dir_name, "lilly.conf")
	config_root_path_label := 'lilly - config root dir (#${path})'
	print_and_exit(config_root_path_label)
}

fn symlink_and_close() {
	$if windows { return }
	mut link_path := "/data/data/com.termux/files/usr/bin/lilly"

	if !os.is_dir("/data/data/com.termux/files") {
		link_dir := os.local_bin_dir()
		if !os.exists(link_dir) {
			os.mkdir_all(link_dir) or { eprintln("failed to symlink: ${err}"); exit(1) }
		}
		link_path = link_dir + "/lilly"
	}

	os.rm(link_path) or {}
	os.symlink(os.executable(), link_path) or {
		eprintln("failed to create symlink '${link_path}'. try again with sudo.")
	}

	println("created symlink ${link_path} successfully")
	exit(0)
}

type WDResolver = fn () string

fn resolve_file_and_workspace_dir_paths(args []string, resolve_wd WDResolver) !(string, string) {
	stripped_args := cmdline.only_non_options(args)
	if stripped_args.len == 0 {
		return '', resolve_wd()
	}
	index := stripped_args.len - 1
	file_or_dir_path := stripped_args[index]
	if os.is_dir(file_or_dir_path) {
		return '', file_or_dir_path
	}

	return file_or_dir_path, os.dir(file_or_dir_path)
}

fn main() {
	mut args := os.args[1..].clone()
	opts := resolve_options_from_args(args)

	if opts.symlink {
		symlink_and_close()
	}

	if opts.show_version {
		output_version_and_close(gitcommit_hash)
	}

	if opts.show_config_root_path {
		output_config_root_path_and_close(os.config_dir()!)
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
	app.lilly = open_lilly(mut l, mut clip, gitcommit_hash, file_path, workspace_path, opts.use_gap_buffer) or {
		print_and_exit('${err}')
		unsafe { nil }
	}

	run()!
}

fn print_and_exit(msg string) {
	println(msg)
	exit(1)
}
