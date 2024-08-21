module workspace

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
	mut expanded_path := path.replace('./', mock_fs.pwd)
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
	for file in mock_fs.files[expanded_path] or { return } {
		f('${expanded_path}/${file}')
	}
}

fn (mock_fs MockFS) read_file(path string) !string {
	if v := mock_fs.file_contents[path] {
		return v
	}
	return error('file ${path} does not exist')
}

fn (mock_fs MockFS) config_dir() !string {
	return '/home/test-user/.config'
}

fn test_open_workspace_loads_builtin_syntax() {
	mock_fs := MockFS{
		pwd:  '/home/test-user/dev/fakeproject'
		dirs: {
			'/home/test-user/dev/fakeproject': []
		}
		files:         {}
		file_contents: {}
	}

	mut mock_log := MockLogger{}
	wrkspace := open_workspace(mut mock_log, './', mock_fs.is_dir, mock_fs.dir_walker,
		mock_fs.config_dir, mock_fs.read_file) or { panic('${err.msg()}') }
	assert wrkspace.syntaxes.len == 4
	assert wrkspace.syntaxes[0].name == 'V'
	assert wrkspace.syntaxes[1].name == 'Go'
	assert wrkspace.syntaxes[2].name == 'C'
	assert wrkspace.syntaxes[3].name == 'Rust'
}

fn test_open_workspace_overrides_builtin_syntax() {
	mock_fs := MockFS{
		pwd:  '/home/test-user/dev/fakeproject'
		dirs: {
			'/home/test-user/.config/lilly/syntaxes': []
			'/home/test-user/dev/fakeproject':        []
		}
		files: {
			'/home/test-user/.config/lilly/syntaxes': ['go.syntax']
		}
		file_contents: {
			'/home/test-user/.config/lilly/syntaxes/go.syntax': '{ "name": "GoTest"}'
		}
	}

	mut mock_log := MockLogger{}
	wrkspace := open_workspace(mut mock_log, './', mock_fs.is_dir, mock_fs.dir_walker,
		mock_fs.config_dir, mock_fs.read_file) or { panic('${err.msg()}') }
	assert wrkspace.syntaxes.len == 4
	assert wrkspace.syntaxes[0].name == 'V'
	assert wrkspace.syntaxes[1].name == 'GoTest'
}

fn test_open_workspace_loads_custom_syntax() {
	mock_fs := MockFS{
		pwd:  '/home/test-user/dev/fakeproject'
		dirs: {
			'/home/test-user/.config/lilly/syntaxes': []
			'/home/test-user/dev/fakeproject':        []
		}
		files: {
			'/home/test-user/.config/lilly/syntaxes': ['brainfuck.syntax']
		}
		file_contents: {
			'/home/test-user/.config/lilly/syntaxes/brainfuck.syntax': '{ "name": "Brainfuck"}'
		}
	}

	mut mock_log := MockLogger{}
	wrkspace := open_workspace(mut mock_log, './', mock_fs.is_dir, mock_fs.dir_walker,
		mock_fs.config_dir, mock_fs.read_file) or { panic('${err.msg()}') }
	assert mock_log.error_msgs.len == 1
	assert mock_log.error_msgs[0] == 'failed to resolve config: local config file /home/test-user/.config/lilly/lilly.conf not found: file /home/test-user/.config/lilly/lilly.conf does not exist'
	assert wrkspace.syntaxes.len == 5
	assert wrkspace.syntaxes[0].name == 'V'
	assert wrkspace.syntaxes[1].name == 'Go'
	assert wrkspace.syntaxes[4].name == 'Brainfuck'
}
