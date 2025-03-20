// Copyright 2025 The Lilly Editor contributors
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

module workspace

import os
import json
import term.ui as tui

const builtin_lilly_config_file_content = $embed_file('../../config/lilly.conf').to_string()
pub const lilly_config_root_dir_name = 'lilly'
const lilly_syntaxes_dir_name = 'syntaxes'

pub struct Workspace {
pub:
	config Config
mut:
	files      []string
	syntaxes   []Syntax
	git_branch string
}

pub interface Logger {
mut:
	error(msg string)
}

pub struct Config {
pub mut:
	leader_key                string
	relative_line_numbers     bool
	selection_highlight_color tui.Color
	insert_tabs_not_spaces    bool
}

pub fn open_workspace(mut _log Logger,
	root_path string,
	is_dir fn (path string) bool,
	dir_walker fn (path string, f fn (string)),
	config_dir fn () !string,
	read_file fn (path string) !string,
	execute fn (cmd string) os.Result
) !Workspace {
	path := root_path
	if !is_dir(path) {
		return error('${path} is not a directory')
	}
	mut wrkspace := Workspace{
		config: resolve_config(mut _log, config_dir, read_file)
	}

	wrkspace.resolve_files(path, is_dir, dir_walker)
	wrkspace.resolve_git_branch_name(execute)
	wrkspace.load_builtin_syntaxes()
	wrkspace.load_syntaxes_from_disk(config_dir, dir_walker, read_file) or {
		return error('unable to load syntaxes')
	}
	return wrkspace
}

fn (mut workspace Workspace) resolve_git_branch_name(execute fn (cmd string) os.Result) {
	prefix := '\uE0A0' // the git branch symbol rune
	wt := spawn currently_in_worktree(execute)
	in_wt := wt.wait()
	if in_wt {
		gb := spawn get_branch(execute)
		branch := gb.wait()
		workspace.git_branch = '${prefix} ${branch}'
	}
}

fn currently_in_worktree(execute fn (cmd string) os.Result) bool {
	res := execute('git rev-parse --is-inside-work-tree')
	return res.exit_code == 0
}

fn get_branch(execute fn (cmd string) os.Result) string {
	res := execute('git branch --show-current')
	return res.output
}

fn (mut workspace Workspace) resolve_files(path string,
	is_dir fn (path string) bool,
	dir_walker fn (path string, f fn (string))
) {
	mut files_ref := &workspace.files
	dir_walker(path, fn [mut files_ref, is_dir] (file_path string) {
		if file_path.contains('.git') {
			return
		}
		// FIX(tauraamui): this doesn't actually work if the passed path isn't just '.'
		if is_dir(file_path) {
			return
		}
		files_ref << file_path
	})
}

pub fn (workspace Workspace) branch() string {
	return workspace.git_branch
}

pub fn (workspace Workspace) get_files() []string {
	return workspace.files
}

pub fn (workspace Workspace) syntaxes() []Syntax {
	return workspace.syntaxes
}

fn resolve_config(mut _log Logger, config_dir fn () !string, read_file fn (path string) !string) Config {
	loaded_config := attempt_to_load_from_disk(config_dir, read_file) or {
		_log.error('failed to resolve config: ${err}')
		return fallback_to_bundled_default_config()
	}
	// loaded_config := attempt_to_load_from_disk(config_dir, read_file) or { fallback_to_bundled_default_config() }
	return loaded_config
}

// NOTE(tauraamui):
// Whilst technically json decode can fail, this should only be the case in this instance
// if we the editor authors have fucked up the default config file format, this kind of
// issue should never make it out to production, hence the acceptable panic here.
fn fallback_to_bundled_default_config() Config {
	return json.decode(Config, builtin_lilly_config_file_content) or {
		panic('decoding bundled config failed: ${err}')
	}
}

fn attempt_to_load_from_disk(config_dir fn () !string, read_file fn (path string) !string) !Config {
	config_root_dir := config_dir() or {
		return error('unable to resolve local config root directory')
	}
	config_file_full_path := os.join_path(config_root_dir, lilly_config_root_dir_name,
		'lilly.conf')
	config_file_contents := read_file(config_file_full_path) or {
		return error('local config file ${config_file_full_path} not found: ${err}')
	}
	return json.decode(Config, config_file_contents) or {
		return error('unable to parse config ${config_file_full_path}: ${err}')
	}
}
