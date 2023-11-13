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
import json
import term.ui as tui

const builtin_lilly_config_file_content = $embed_file('config/lilly.conf').to_string()

const (
	home_dir     = os.home_dir()
	settings_dir = os.join_path(home_dir, '.lilly')
	syntax_dir   = os.join_path(settings_dir, 'syntax')
)

struct Config {
mut:
	relative_line_numbers bool
	selection_highlight_color tui.Color
	insert_tabs_not_spaces bool
}

fn (mut view View) load_config() {
	println("loading config...")
	config := json.decode(Config, builtin_lilly_config_file_content) or {
		panic("the builtin config file can not be decoded")
	}
	view.config = config
}
