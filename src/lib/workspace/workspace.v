module workspace

import os
import term.ui as tui

pub struct Workspace {
pub:
	config Config
mut:
	files []string
}

struct Config {
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
	return attempt_to_load_from_disk() or { fallback_to_bundled_default_config() }
}

fn fallback_to_bundled_default_config() Config {
	return Config{}
}

fn attempt_to_load_from_disk() !Config {
	return Config{}
}

pub fn (workspace Workspace) files() []string {
	return workspace.files
}
