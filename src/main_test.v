module main

fn wd_resolver() string {
	return "test-workspace"
}

fn test_resolve_file_and_workspace_dir_paths() {
	mut file_path, mut workspace_path := resolve_file_and_workspace_dir_paths([], wd_resolver)!
	assert file_path == ""
	assert workspace_path == "test-workspace"

	file_path, workspace_path = resolve_file_and_workspace_dir_paths(["./random-dir/test-file.txt"], wd_resolver)!
	assert file_path == "./random-dir/test-file.txt"
	assert workspace_path == "./random-dir"
}
