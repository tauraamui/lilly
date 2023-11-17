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
	// return error("workspace not implemented yet")
	wrkspace := Workspace{}
	mut files_ref := &wrkspace.files
	dir_walker(path, fn [mut files_ref] (file_path string) {
		files_ref << file_path
	})
	return wrkspace
}

pub fn (workspace Workspace) files() []string {
	return workspace.files
}
