module workspace

import term.ui as tui

struct MockLogger {
mut:
	error_msgs []string
}

fn (mut mock_log MockLogger) error(msg string) {
	mock_log.error_msgs << msg
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
		pwd:  '/dev/fake-project'
		dirs: {
			'/home/test-user/.config/lilly': []
			'/dev/fake-project':             ['.git', 'src', 'research-notes']
		}
		files: {
			'/home/test-user/.config/lilly':        ['lilly.conf']
			'/dev/fake-project/.git/8494859384953': ['something.patch']
			'/dev/fake-project/src':                ['main.v', 'some_other_code.v']
			'/dev/fake-project/research-notes':     ['brainstorm.pdf', 'article-links.txt']
		}
		file_contents: {
			'/home/test-user/.config/lilly/lilly.conf': '{ "relative_line_numbers": true, "insert_tabs_not_spaces": false, "selection_highlight_color": { "r": 96, "g": 138, "b": 143 } }'
		}
	}
	mut mock_log := MockLogger{}
	wrkspace := open_workspace(mut mock_log, './', mock_fs.is_dir, mock_fs.dir_walker,
		mock_fs.config_dir, mock_fs.read_file) or { panic('${err}') }

	assert wrkspace.files == [
		'/dev/fake-project/src/main.v',
		'/dev/fake-project/src/some_other_code.v',
		'/dev/fake-project/research-notes/brainstorm.pdf',
		'/dev/fake-project/research-notes/article-links.txt',
	]

	assert wrkspace.config == Config{
		relative_line_numbers:     true
		selection_highlight_color: tui.Color{
			r: 96
			g: 138
			b: 143
		}
		insert_tabs_not_spaces: false
	}
}

fn test_open_workspace_files_but_fallsback_to_embedded_config() {
	mock_fs := MockFS{
		pwd:  '/dev/fake-project'
		dirs: {
			'/home/test-user/.config/lilly': []
			'/dev/fake-project':             ['src', 'research-notes']
		}
		files: {
			'/dev/fake-project/src':            ['main.v', 'some_other_code.v']
			'/dev/fake-project/research-notes': ['brainstorm.pdf', 'article-links.txt']
		}
		file_contents: {}
	}
	mut mock_log := MockLogger{}
	wrkspace := open_workspace(mut mock_log, './', mock_fs.is_dir, mock_fs.dir_walker,
		mock_fs.config_dir, mock_fs.read_file) or { panic('${err}') }

	assert wrkspace.files == [
		'/dev/fake-project/src/main.v',
		'/dev/fake-project/src/some_other_code.v',
		'/dev/fake-project/research-notes/brainstorm.pdf',
		'/dev/fake-project/research-notes/article-links.txt',
	]

	assert wrkspace.config == Config{
		leader_key:                ' '
		relative_line_numbers:     true
		selection_highlight_color: tui.Color{
			r: 96
			g: 138
			b: 143
		}
		insert_tabs_not_spaces: true
	}
}

fn test_open_workspace_resolves_git_branch() {
	mock_fs := MockFS{
		pwd:  '/dev/fake-project'
		dirs: {
			'/home/test-user/.config/lilly': []
			'/dev/fake-project':             ['.git', 'src', 'research-notes']
			'/dev/fake-project/.git':        ['src', 'research-notes']
		}
		files: {
			'/dev/fake-project/.git':           ['HEAD']
			'/dev/fake-project/src':            ['main.v', 'some_other_code.v']
			'/dev/fake-project/research-notes': ['brainstorm.pdf', 'article-links.txt']
		}
		file_contents: {
			'/dev/fake-project/.git/HEAD': 'ref: refs/heads/feat/git-branch-status-line'
		}
	}
	mut mock_log := MockLogger{}
	wrkspace := open_workspace(mut mock_log, './', mock_fs.is_dir, mock_fs.dir_walker,
		mock_fs.config_dir, mock_fs.read_file) or { panic('${err}') }

	assert wrkspace.git_branch == '\uE0A0 feat/git-branch-status-line'

	assert wrkspace.files == [
		'/dev/fake-project/src/main.v',
		'/dev/fake-project/src/some_other_code.v',
		'/dev/fake-project/research-notes/brainstorm.pdf',
		'/dev/fake-project/research-notes/article-links.txt',
	]

	assert wrkspace.config == Config{
		leader_key:                ' '
		relative_line_numbers:     true
		selection_highlight_color: tui.Color{
			r: 96
			g: 138
			b: 143
		}
		insert_tabs_not_spaces: true
	}
}
