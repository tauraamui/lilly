module workspace

struct MockFS {
	pwd           string
	dirs          map[string][]string
	files         map[string][]string
	file_contents map[string]string
}

fn (mock_fs MockFS) is_dir(path string) bool {
	mut expanded_path := path.replace(".config", "").replace(".", mock_fs.pwd)
	_ := mock_fs.dirs[expanded_path] or { return false }
	return true
}

fn (mock_fs MockFS) dir_walker(path string, f fn (string)) {
	mut expanded_path := path.replace(".config", "dotconfig").replace(".", mock_fs.pwd).replace("dotconfig", ".config")
	sub_dirs := mock_fs.dirs[expanded_path] or { return }
	for sub_dir in sub_dirs {
		full_dir := "${expanded_path}/${sub_dir}"
		sub_dir_files := mock_fs.files[full_dir] or { continue }
		for sub_dir_file in sub_dir_files {
			f("${full_dir}/${sub_dir_file}")
		}
	}
	for file in mock_fs.files[expanded_path] or { return } {
		f("${expanded_path}/${file}")
	}
}

fn (mock_fs MockFS) read_file(path string) !string {
	if v := mock_fs.file_contents[path] {
		return v
	}
	return error("file ${path} does not exist")
}

fn (mock_fs MockFS) config_dir() !string {
	return "/home/test-user/.config"
}

fn test_open_workspace_loads_builtin_syntax() {
	mock_fs := MockFS{
		pwd: "/home/test-user/dev/fakeproject"
		dirs: {
			"/home/test-user/dev/fakeproject": []
		}
		files: {}
		file_contents: {}
	}

	wrkspace := open_workspace("./", mock_fs.is_dir, mock_fs.dir_walker, mock_fs.config_dir, mock_fs.read_file) or { panic("${err.msg()}") }
	assert wrkspace.syntaxes[0].name == "V"
	assert wrkspace.syntaxes[1].name == "Go"
}

fn test_open_workspace_overrides_builtin_syntax() {
	mock_fs := MockFS{
		pwd: "/home/test-user/dev/fakeproject"
		dirs: {
			"/home/test-user/.config/lilly/syntaxes": [],
			"/home/test-user/dev/fakeproject": []
		}
		files: {
			"/home/test-user/.config/lilly/syntaxes": ["go.syntax"]
		}
		file_contents: {
			"/home/test-user/.config/lilly/syntaxes/go.syntax": '{ "name": "GoTest"}'
		}
	}

	wrkspace := open_workspace("./", mock_fs.is_dir, mock_fs.dir_walker, mock_fs.config_dir, mock_fs.read_file) or { panic("${err.msg()}") }
	assert wrkspace.syntaxes[0].name == "V"
	assert wrkspace.syntaxes[1].name == "GoTest"
}
