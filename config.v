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

module cfg

import lib.petal.theme

pub const light_theme_name = theme.light_theme_name
pub const dark_theme_name = theme.dark_theme_name

pub struct Config {
pub:
	theme      theme.Theme
	leader_key string
}

@[params]
pub struct ConfigOptions {
pub:
	load_from_path ?string = '~/.config/petal/petal.cfg'
}

pub fn Config.new(opts ConfigOptions) Config {
	if path_to_load := opts.load_from_path {
		assert path_to_load.len > 0
		// do some loading from file here
		// return Config{}
	}

	return Config{
		theme:      theme.dark_theme
		leader_key: ';'
	}
}

pub fn (c Config) set_theme(name string) Config {
	return Config{
		...c
		theme: if name == 'dark' { theme.dark_theme } else { theme.light_theme }
	}
}
