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

import term.ui as tui
import os

struct MockLogger {
mut:
	error_msgs []string
}

fn (mut mock_log MockLogger) error(msg string) {
	mock_log.error_msgs << msg
}

struct MockOS {
	branch    string
	exit_code int
}

fn (mock_os MockOS) execute(cmd string) os.Result {
	match cmd {
		'git rev-parse --is-inside-work-tree' {
			return os.Result{
				exit_code: mock_os.exit_code
			}
		}
		'git branch --show-current' {
			return os.Result{
				exit_code: mock_os.exit_code
				output:    mock_os.branch
			}
		}
		else {
			return os.Result{
				exit_code: 1
				output:    'no matching command found'
			}
		}
	}
}

struct MockFS {
	pwd           string
	dirs          map[string][]string
	files         map[string][]string
	file_contents map[string]string
}

fn (mock_fs MockFS) is_dir(path string) bool {
	mut expanded_path := path.replace('./', mock_fs.pwd).replace('.git', '/.git')
	if mock_fs.pwd == expanded_path {
		return true
	}
	_ := mock_fs.dirs[expanded_path] or { return false }
	return true
}

fn (mock_fs MockFS) dir_walker(path string, f fn (string)) {
	mut expanded_path := path.replace('./', mock_fs.pwd)
	sub_dirs := mock_fs.dirs[expanded_path] or { return }
	for sub_dir in sub_dirs {
		full_dir := '${expanded_path}/${sub_dir}'
		sub_dir_files := mock_fs.files[full_dir] or { continue }
		for sub_dir_file in sub_dir_files {
			f('${full_dir}/${sub_dir_file}')
		}
	}
}

fn (mock_fs MockFS) read_file(path string) !string {
	expanded_path := path.replace('./', mock_fs.pwd).replace('.git', '/.git')
	if v := mock_fs.file_contents[expanded_path] {
		return v
	}
	return error('file ${path} does not exist')
}

fn (mock_fs MockFS) config_dir() !string {
	return '/home/test-user/.config'
}

fn test_open_workspace_files_and_config() {
	mock_fs := MockFS{
		pwd:           '/dev/fake-project'
		dirs:          {
			'/home/test-user/.config/lilly': []
			'/dev/fake-project':             ['.git', 'src', 'research-notes']
		}
		files:         {
			'/home/test-user/.config/lilly':        ['lilly.conf']
			'/dev/fake-project/.git/8494859384953': ['something.patch']
			'/dev/fake-project/src':                ['main.v', 'some_other_code.v']
			'/dev/fake-project/research-notes':     ['brainstorm.pdf', 'article-links.txt']
		}
		file_contents: {
			'/home/test-user/.config/lilly/lilly.conf': '{ "leader_key": ";", "relative_line_numbers": true, "insert_tabs_not_spaces": false, "selection_highlight_color": { "r": 96, "g": 138, "b": 143 } }'
		}
	}

	mock_os := MockOS{
		branch:    'git-branch-status-line'
		exit_code: 0
	}

	mut mock_log := MockLogger{}
	cfg := resolve_config(mut mock_log, mock_fs.config_dir, mock_fs.read_file)
	wrkspace := open_workspace(mut mock_log, './', mock_fs.is_dir, mock_fs.dir_walker,
		cfg, mock_fs.config_dir, mock_fs.read_file, mock_os.execute) or { panic('${err}') }

	assert wrkspace.files == [
		'/dev/fake-project/src/main.v',
		'/dev/fake-project/src/some_other_code.v',
		'/dev/fake-project/research-notes/brainstorm.pdf',
		'/dev/fake-project/research-notes/article-links.txt',
	]

	assert wrkspace.config == Config{
		leader_key:             ';'
		relative_line_numbers:  true
		insert_tabs_not_spaces: false
	}
}

fn test_workspace_config_resolves_no_background_if_missing() {
	mock_fs := MockFS{
		pwd:           '/dev/fake-project'
		dirs:          {
			'/home/test-user/.config/lilly': []
			'/dev/fake-project':             ['.git', 'src', 'research-notes']
		}
		files:         {
			'/home/test-user/.config/lilly':        ['lilly.conf']
			'/dev/fake-project/.git/8494859384953': ['something.patch']
			'/dev/fake-project/src':                ['main.v', 'some_other_code.v']
			'/dev/fake-project/research-notes':     ['brainstorm.pdf', 'article-links.txt']
		}
		file_contents: {
			'/home/test-user/.config/lilly/lilly.conf': '{ "relative_line_numbers": true, "insert_tabs_not_spaces": false, "selection_highlight_color": { "r": 101, "g": 75, "b": 143 } }'
		}
	}

	mock_os := MockOS{
		branch:    'git-branch-status-line'
		exit_code: 0
	}

	mut mock_log := MockLogger{}
	cfg := resolve_config(mut mock_log, mock_fs.config_dir, mock_fs.read_file)
	wrkspace := open_workspace(mut mock_log, './', mock_fs.is_dir, mock_fs.dir_walker,
		cfg, mock_fs.config_dir, mock_fs.read_file, mock_os.execute) or { panic('${err}') }

	assert wrkspace.files == [
		'/dev/fake-project/src/main.v',
		'/dev/fake-project/src/some_other_code.v',
		'/dev/fake-project/research-notes/brainstorm.pdf',
		'/dev/fake-project/research-notes/article-links.txt',
	]

	assert wrkspace.config == Config{
		relative_line_numbers:  true
		insert_tabs_not_spaces: false
	}
}

fn test_workspace_config_resolves_no_selection_highlight_color_if_missing() {
	mock_fs := MockFS{
		pwd:           '/dev/fake-project'
		dirs:          {
			'/home/test-user/.config/lilly': []
			'/dev/fake-project':             ['.git', 'src', 'research-notes']
		}
		files:         {
			'/home/test-user/.config/lilly':        ['lilly.conf']
			'/dev/fake-project/.git/8494859384953': ['something.patch']
			'/dev/fake-project/src':                ['main.v', 'some_other_code.v']
			'/dev/fake-project/research-notes':     ['brainstorm.pdf', 'article-links.txt']
		}
		file_contents: {
			'/home/test-user/.config/lilly/lilly.conf': '{ "relative_line_numbers": true, "insert_tabs_not_spaces": false, "background_color": { "r": 96, "g": 138, "b": 143 } }'
		}
	}

	mock_os := MockOS{
		branch:    'git-branch-status-line'
		exit_code: 0
	}

	mut mock_log := MockLogger{}
	cfg := resolve_config(mut mock_log, mock_fs.config_dir, mock_fs.read_file)
	wrkspace := open_workspace(mut mock_log, './', mock_fs.is_dir, mock_fs.dir_walker,
		cfg, mock_fs.config_dir, mock_fs.read_file, mock_os.execute) or { panic('${err}') }

	assert wrkspace.files == [
		'/dev/fake-project/src/main.v',
		'/dev/fake-project/src/some_other_code.v',
		'/dev/fake-project/research-notes/brainstorm.pdf',
		'/dev/fake-project/research-notes/article-links.txt',
	]

	assert wrkspace.config == Config{
		relative_line_numbers:  true
		insert_tabs_not_spaces: false
	}
}

fn test_open_workspace_files_but_fallsback_to_embedded_config() {
	mock_fs := MockFS{
		pwd:           '/dev/fake-project'
		dirs:          {
			'/home/test-user/.config/lilly': []
			'/dev/fake-project':             ['src', 'research-notes']
		}
		files:         {
			'/dev/fake-project/src':            ['main.v', 'some_other_code.v']
			'/dev/fake-project/research-notes': ['brainstorm.pdf', 'article-links.txt']
		}
		file_contents: {}
	}

	mock_os := MockOS{
		branch:    'git-branch-status-line'
		exit_code: 0
	}

	mut mock_log := MockLogger{}
	cfg := resolve_config(mut mock_log, mock_fs.config_dir, mock_fs.read_file)
	wrkspace := open_workspace(mut mock_log, './', mock_fs.is_dir, mock_fs.dir_walker,
		cfg, mock_fs.config_dir, mock_fs.read_file, mock_os.execute) or { panic('${err}') }

	assert wrkspace.files == [
		'/dev/fake-project/src/main.v',
		'/dev/fake-project/src/some_other_code.v',
		'/dev/fake-project/research-notes/brainstorm.pdf',
		'/dev/fake-project/research-notes/article-links.txt',
	]

	assert wrkspace.config == Config{
		leader_key:             ' '
		relative_line_numbers:  true
		insert_tabs_not_spaces: true
		theme:                  'petal'
	}
}

fn test_open_workspace_resolves_git_branch() {
	mock_fs := MockFS{
		pwd:           '/dev/fake-project'
		dirs:          {
			'/home/test-user/.config/lilly': []
			'/dev/fake-project':             ['.git', 'src', 'research-notes']
			'/dev/fake-project/.git':        ['src', 'research-notes']
		}
		files:         {
			'/dev/fake-project/.git':           ['HEAD']
			'/dev/fake-project/src':            ['main.v', 'some_other_code.v']
			'/dev/fake-project/research-notes': ['brainstorm.pdf', 'article-links.txt']
		}
		file_contents: {}
	}

	mock_os := MockOS{
		branch:    'feat/git-branch-status-line'
		exit_code: 0
	}

	mut mock_log := MockLogger{}
	cfg := resolve_config(mut mock_log, mock_fs.config_dir, mock_fs.read_file)
	wrkspace := open_workspace(mut mock_log, './', mock_fs.is_dir, mock_fs.dir_walker,
		cfg, mock_fs.config_dir, mock_fs.read_file, mock_os.execute) or { panic('${err}') }

	assert wrkspace.git_branch == '\uE0A0 feat/git-branch-status-line'

	assert wrkspace.files == [
		'/dev/fake-project/src/main.v',
		'/dev/fake-project/src/some_other_code.v',
		'/dev/fake-project/research-notes/brainstorm.pdf',
		'/dev/fake-project/research-notes/article-links.txt',
	]

	assert wrkspace.config == Config{
		leader_key:             ' '
		relative_line_numbers:  true
		insert_tabs_not_spaces: true
		theme:                  'petal'
	}
}
