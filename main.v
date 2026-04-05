// Copyright 2026 The Lilly Edtior contributors
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

import flag
import os
import v.vmod
import tauraamui.bobatea as tea
import cfg
import lib.documents
import lib.clipboard
import lib.telemetry

const mod_file_content = $embed_file('v.mod').to_string()

// application help desc and supported flags
@[xdoc: 'a modern editor for your terminal']
@[version: 'unknown']
@[name: 'lilly']
struct CfgArgs {
	show_version bool @[short: v; xdoc: 'Show version and exit']
	show_help    bool @[long: help; short: h]
	symlink      bool @[long: symlink; short: s]
	no_matches   []string
}

struct OsFns {
	is_dir     fn (p string) bool                @[required]
	exists     fn (p string) bool                @[required]
	mkdir_all  fn (p string) !                   @[required]
	rm         fn (p string) !                   @[required]
	symlink    fn (origin string, dest string) ! @[required]
	executable fn () string                      @[required]
	home_dir   fn () string                      @[required]
	getenv_opt fn (key string) ?string           @[required]
	exit       fn (code int)                     @[required]
}

fn resolve_cfg_args_from_args[T](args []string, v_manifest vmod.Manifest) !(T, []string) {
	args_cfg, no_matches := flag.to_struct[T](args, skip: 1) or {
		return error('unexpected error: ${err}')
	}
	if args_cfg.show_help || no_matches.len > 1 {
		help_doc := flag.to_doc[T](version: v_manifest.version)!
		println(help_doc)
		exit(if no_matches.len > 1 { 1 } else { 0 })
	}
	return args_cfg, no_matches
}

fn execute_on_flags(args_cfg CfgArgs, version string, os_fns OsFns) ! {
	match true {
		args_cfg.show_version {
			println('lilly - version ${version}')
			os_fns.exit(0)
		}
		args_cfg.symlink {
			$if windows {
				return error('symlink not implemented for Windows yet')
			}
			mut link_path := '/data/data/com.termux/files/usr/bin/lilly'
			if !os_fns.is_dir('/data/data/com.termux/files') {
				link_dir := '/usr/local/bin'
				if !os_fns.exists(link_dir) {
					os_fns.mkdir_all(link_dir) or {
						eprintln('Failed to create symlink "${link_path}": ${err}')
						eprintln('Try again with sudo.')
						os_fns.exit(1)
						return
					}
				}
				link_path = link_dir + '/lilly'
			}
			os_fns.rm(link_path) or {}
			os_fns.symlink(os_fns.executable(), link_path) or {
				// Try ~/.local/bin as a fallback when /usr/local/bin is not writable.
				home := os_fns.home_dir()
				if home == '' {
					eprintln('Failed to create symlink "${link_path}": ${err}')
					eprintln('Try again with sudo.')
					os_fns.exit(1)
					return
				}
				local_bin := os.join_path(home, '.local', 'bin')
				if !os_fns.exists(local_bin) {
					os_fns.mkdir_all(local_bin) or {
						eprintln('Failed to create symlink "${link_path}": ${err}')
						eprintln('Try again with sudo.')
						os_fns.exit(1)
						return
					}
				}
				link_path = os.join_path(local_bin, 'lilly')
				os_fns.rm(link_path) or {}
				os_fns.symlink(os_fns.executable(), link_path) or {
					eprintln('Failed to create symlink "${link_path}": ${err}')
					eprintln('Try again with sudo.')
					os_fns.exit(1)
					return
				}
				eprintln('Note: Symlink created in "${local_bin}" instead of "/usr/local/bin".')
				if path := os_fns.getenv_opt('PATH') {
					if !path.contains(local_bin) {
						eprintln('Make sure "${local_bin}" is in your PATH.')
					}
				}
			}
			os_fns.exit(0)
		}
		else {}
	}
}

fn resolve_initial_file_path_and_chdir(no_matches []string, real_path fn (s string) string, is_dir fn (p string) bool, chdir fn (p string) !) ?string {
	if no_matches.len == 1 {
		provided_path := real_path(no_matches[0])
		if is_dir(provided_path) {
			chdir(provided_path) or {}
		} else {
			parent_dir := os.dir(provided_path)
			chdir(parent_dir) or {}
			return provided_path
		}
	}
	return ?string(none)
}

fn main() {
	$if windows {
		eprintln('Windows is not supported at this time')
		return
	}

	vmod_manifest := vmod.decode(mod_file_content) or { panic('failed to parse v.mod: ${err}') }
	args_cfg, no_matches := resolve_cfg_args_from_args[CfgArgs](os.args, vmod_manifest)!

	version := '${vmod_manifest.version} (#${build_id})'
	execute_on_flags(args_cfg, version, OsFns{
		is_dir:     os.is_dir
		exists:     os.exists
		mkdir_all:  fn (p string) ! {
			return os.mkdir_all(p)
		}
		rm:         os.rm
		symlink:    os.symlink
		executable: os.executable
		home_dir:   os.home_dir
		getenv_opt: fn (key string) ?string {
			return os.getenv_opt(key)
		}
		exit:       exit
	}) or {
		eprintln('unexpected error: ${err}')
		exit(1)
	}

	persist_stderr_to_disk()

	initial_file_path := resolve_initial_file_path_and_chdir(no_matches, os.real_path,
		os.is_dir, os.chdir)

	theme_name := os.getenv('LILLY_THEME')
	config := cfg.Config.new(load_from_path: none).set_theme(theme_name)

	mut documents_controller := documents.Controller.new()
	defer { documents_controller.free() }

	emit_metrics_maybe(vmod_manifest)

	mut cb := clipboard.new()
	mut petal_model := PetalModel.new(version, config, &documents_controller, &cb,
		initial_file_path: initial_file_path
	)
	mut app := tea.new_program(mut petal_model)
	petal_model.app_send = app.send
	app.run() or { panic('something went wrong! ${err}') }
}

fn emit_metrics_maybe(manifest vmod.Manifest) {
	tp := if os.getenv('LILLY_NO_TELEMETRY') != '' {
		telemetry.Provider(telemetry.NoOpProvider{})
	} else {
		telemetry.Provider(telemetry.HttpProvider.new('https://tauraamui.website/api/v1/lilly-ping'))
	}

	spawn tp.send_event(telemetry.Event{
		kind:    .launch
		version: manifest.version
		os:      os.uname().sysname
		arch:    os.uname().machine
	})
}



