module main

import os
import json

const builtin_lilly_config_file_content = $embed_file('config/lilly.conf').to_string()

const (
	home_dir     = os.home_dir()
	settings_dir = os.join_path(home_dir, '.lilly')
	syntax_dir   = os.join_path(settings_dir, 'syntax')
)

struct Config {
mut:
	relative_line_numbers bool
}

fn (mut view View) load_config() {
	println("loading config...")
	config := json.decode(Config, builtin_lilly_config_file_content) or {
		panic("the builtin config file can not be decoded")
	}
	view.config = config
}
