module workspace

struct MockFS {
	pwd   string
	dirs  map[string][]string
	files map[string][]string
}

fn (mock_fs MockFS) is_dir(path string) bool {
	mut expanded_path := path.replace(".", mock_fs.pwd)
	_ := mock_fs.dirs[expanded_path] or { return false }
	return true
}

fn (mock_fs MockFS) dir_walker(path string, f fn (string)) {
	mut expanded_path := path.replace(".", mock_fs.pwd)
	sub_dirs := mock_fs.dirs[expanded_path] or { return }
	for sub_dir in sub_dirs {
		full_dir := "${expanded_path}/${sub_dir}"
		sub_dir_files := mock_fs.files[full_dir] or { continue }
		for sub_dir_file in sub_dir_files {
			f("${full_dir}/${sub_dir_file}")
		}
	}
}

fn test_open_workspace() {
	mock_fs := MockFS{
		pwd:  "/dev/fake-project"
		dirs: { "/dev/fake-project": ["src"] }
		files: { "/dev/fake-project/src": ["main.v", "some_other_code.v"] }
	}
	wrkspace := open_workspace("./", mock_fs.is_dir, mock_fs.dir_walker) or { panic("${err}") }

	assert wrkspace.files == [
		"/dev/fake-project/src/main.v",
		"/dev/fake-project/src/some_other_code.v"
	]
}

