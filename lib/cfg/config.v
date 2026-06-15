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
import kdlv
import lib.petal.theme

pub const light_theme_name = theme.light_theme_name
pub const dark_theme_name = theme.dark_theme_name

pub const default_config = Config{
    theme: theme.dark_theme
    leader_key: ';'
    tab_width: 4
    relative_line_numbers: true
}

pub struct Config {
pub:
	theme                 theme.Theme
	leader_key            string
	tab_width             int
	relative_line_numbers bool
}

pub struct ConfigFile {
pub mut:
	theme                 string
	leader_key            string
	tab_width             int
	relative_line_numbers bool
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

fn resolve_theme_name(config_name string, override_name string) string {
    if override_name.len > 0 {
        return override_name
    }
    return config_name
}

fn resolve_theme(name string) theme.Theme {
    return match name.trim_space() {
		'light' { theme.light_theme }
		'dark' { theme.dark_theme }
		else { default_config.theme }
    }
}

fn resolve_leader_key(leader_key string) string {
    return if leader_key.len == 1 { leader_key } else { default_config.leader_key }
}

fn resolve_tab_width(width int) int {
    return if width > 0 { width } else { default_config.tab_width }
}

pub fn parse_config_file(file_path string) !Config {
	$if !windows {
		file := os.read_file(os.expand_tilde_to_home(file_path))!

		doc := kdlv.parse(file)!
		if doc.nodes.len == 0 {
			return error('empty config file')
		}

		if doc.nodes[0].name != 'config' {
			return error('no config node')
		}

		mut config := kdlv.decode[ConfigFile](kdlv.generate(kdlv.Document{
			nodes: doc.nodes[0].children
		}, kdlv.GenerateOptions{}))!

        return Config{
            theme: resolve_theme(resolve_theme_name(config.theme, os.getenv('LILLY_THEME')))
            leader_key: resolve_leader_key(config.leader_key)
            tab_width: resolve_tab_width(config.tab_width)
            relative_line_numbers: config.relative_line_numbers
        }
	}
	
    return default_config
}

pub fn Config.new(opts ConfigOptions) Config {
	if path_to_load := opts.load_from_path {
		if parsed_config := parse_config_file(path_to_load) {
			return parsed_config
		}
	}

	for path in xdg_config_paths() {
		if parsed_config := parse_config_file(path) {
			return parsed_config
		}
	}

    return default_config
}

