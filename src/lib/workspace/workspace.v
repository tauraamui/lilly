module workspace

import os
import json
import term.ui as tui

const builtin_lilly_config_file_content = $embed_file("../../config/lilly.conf").to_string()

pub struct Workspace {
pub:
	config Config
mut:
	files []string
}

pub struct Config {
pub mut:
	relative_line_numbers     bool
	selection_highlight_color tui.Color
	insert_tabs_not_spaces    bool
}

pub fn open_workspace(
	root_path string,
	is_dir fn (path string) bool,
	dir_walker fn (path string, f fn (string))
) !Workspace {
	path := os.dir(root_path)
	if !is_dir(path) { return error("${path} is not a directory") }
	wrkspace := Workspace{
		config: resolve_config()
	}
	mut files_ref := &wrkspace.files
	dir_walker(path, fn [mut files_ref, is_dir] (file_path string) {
		if file_path.starts_with("./.git") { return }
		if is_dir(file_path) { return }
		files_ref << file_path
	})
	return wrkspace
}

fn resolve_config() Config {
	loaded_config := attempt_to_load_from_disk() or { fallback_to_bundled_default_config() }
	return loaded_config
}

// NOTE(tauraamui):
// Whilst technically json decode can fail, this should only be the case in this instance
// if we the editor authors have fucked up the default config file format, this kind of
// issue should never make it out to production, hence the acceptable panic here.
fn fallback_to_bundled_default_config() Config {
	return json.decode(Config, builtin_lilly_config_file_content) or { panic("decoding bundled config failed: ${err}") }
}

fn attempt_to_load_from_disk() !Config {
	return error("unable to load user provided config")
}

pub fn (workspace Workspace) files() []string {
	return workspace.files
}
