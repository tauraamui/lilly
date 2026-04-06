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

import os
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
	// TODO(valxntine) [06/04/2026]: keeping this for now until we discuss potential --config CLI flags
	// also keeping this in Config.new to allow the provided path to take precendence over everything
	load_from_path ?string
}

fn xdg_config_paths() []string {
	mut paths := []string{}

	cfg_home := os.getenv('XDG_CONFIG_HOME')
	if cfg_home.len > 0 && os.is_abs_path(cfg_home) {
		paths << os.join_path(cfg_home, 'lilly', 'lilly.cfg')
	} else {
		paths << os.join_path(os.home_dir(), '.config', 'lilly', 'lilly.cfg')
	}

	cfg_dirs := os.getenv('XDG_CONFIG_DIRS')
	dirs := if cfg_dirs.len > 0 { cfg_dirs.split(':') } else { ['/etc/xdg'] }
	for dir in dirs {
		if os.is_abs_path(dir) {
			paths << os.join_path(dir, 'lilly', 'lilly.cfg')
		}
	}

	return paths
}

fn parse_config_file(file_path string) !Config {
	mut ttheme := theme.dark_theme
	mut leader_key := ';'

	$if !windows {
		file := os.read_file(os.expand_tilde_to_home(file_path))!

		for line in file.split_into_lines() {
			trimmed := line.trim_space()

			if trimmed.starts_with('#') || trimmed.len == 0 {
				continue
			}

			pair := trimmed.split('=')

			if pair.len != 2 {
				return error('line does not have a pair')
			}

			key := pair[0].trim_space()
			value := pair[1].trim_space()

			match key {
				'theme' {
					if value == 'dark' {
						ttheme = theme.dark_theme
					} else if value == 'light' {
						ttheme = theme.light_theme
					} else {
						return error('unknown theme')
					}
				}
				'leader' {
					if value[0] != `"` {
						return error('expected " at the start')
					}

					if value[value.len - 1] != `"` {
						return error('expected " at the end')
					}
					leader_key = value.trim('"')
				}
				else {
					return error('unknown key')
				}
			}
		}
	}

	return Config{
		theme:      ttheme
		leader_key: leader_key
	}
}

pub fn Config.new(opts ConfigOptions) Config {
	if path_to_load := opts.load_from_path {
		assert path_to_load.len > 0

		if parsed_config := parse_config_file(path_to_load) {
			return parsed_config
		}
	}

	for path in xdg_config_paths() {
		if parsed_config := parse_config_file(path) {
			return parsed_config
		}
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
