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
}

fn main() {
	vmod_manifest := vmod.decode(mod_file_content) or { panic('failed to parse v.mod: ${err}') }

	args_cfg, no_matches := flag.to_struct[CfgArgs](os.args, skip: 1)!
	if args_cfg.show_help || no_matches.len > 1 {
		help_doc := flag.to_doc[CfgArgs](version: vmod_manifest.version)!
		println(help_doc)
		exit(if no_matches.len > 1 { 1 } else { 0 })
	}

	if args_cfg.show_version {
		println('lilly - version ${vmod_manifest.version}')
		exit(0)
	}

	mut initial_file_path := ?string(none)
	if no_matches.len == 1 {
		provided_path := os.real_path(no_matches[0])
		if os.is_dir(provided_path) {
			os.chdir(provided_path) or {}
		} else {
			parent_dir := os.dir(provided_path)
			os.chdir(parent_dir) or {}
			initial_file_path = provided_path
		}
	}

	theme_name := os.getenv('PETAL_THEME')
	config := cfg.Config.new(load_from_path: none).set_theme(theme_name)

	mut documents_controller := documents.Controller.new()
	defer { documents_controller.free() }

	emit_metrics_maybe(vmod_manifest)

	mut cb := clipboard.new()
	mut petal_model := PetalModel.new(vmod_manifest.version, config, &documents_controller,
		&cb, initial_file_path: initial_file_path)
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
