module workspace

import os

pub struct Workspace {
mut:
	files []string
}

pub struct Modal {
}

pub fn open_workspace(
	root_path string,
	is_dir fn (path string) bool,
	dir_walker fn (path string, f fn (string))
) !Workspace {
	path := os.dir(root_path)
	if !is_dir(path) { return error("${path} is not a directory") }
	wrkspace := Workspace{}
	mut files_ref := &wrkspace.files
	dir_walker(path, fn [mut files_ref, is_dir] (file_path string) {
		if file_path.starts_with("./.git") { return }
		if is_dir(file_path) { return }
		files_ref << file_path
	})
	return wrkspace
}

pub fn (workspace Workspace) files() []string {
	return workspace.files
}