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

import os
import v.vmod
import tauraamui.bobatea as tea
import cfg
import lib.documents
import lib.clipboard

const mod_file_content = $embed_file('v.mod').to_string()

fn main() {
	vmod_manifest := vmod.decode(mod_file_content) or { panic('failed to parse v.mod: ${err}') }
	theme_name := os.getenv('PETAL_THEME')
	config := cfg.Config.new(load_from_path: none).set_theme(theme_name)

	mut documents_controller := documents.Controller.new()
	defer { documents_controller.free() }

	mut cb := clipboard.new()

	mut petal_model := PetalModel.new(vmod_manifest.version, config, &documents_controller, &cb)
	mut app := tea.new_program(mut petal_model)
	petal_model.app_send = app.send
	app.run() or { panic('something went wrong! ${err}') }
}
