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
	mut wrkspace := Workspace{}
	dir_walker(path, fn [mut wrkspace] (file_path string) {
		wrkspace.files << file_path
	})
	return wrkspace
}

pub fn (workspace Workspace) files() []string {
	return workspace.files
}

