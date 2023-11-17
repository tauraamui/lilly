module workspace

import os

pub struct Workspace {
}

pub fn open_workspace(root_path string) !Workspace {
	if !os.is_dir(root_path) { return error("${root_path} is not a directory") }
	return error("workspace not implemented yet")
}

