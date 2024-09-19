module main

fn wd_resolver() string {
	return 'test-workspace'
}

fn test_resolve_file_and_workspace_dir_paths() {
	mut file_path, mut workspace_path := resolve_file_and_workspace_dir_paths([], wd_resolver)!
	assert file_path == ''
	assert workspace_path == 'test-workspace'

	file_path, workspace_path = resolve_file_and_workspace_dir_paths([
		'./random-dir/test-file.txt',
	], wd_resolver)!
	assert file_path == './random-dir/test-file.txt'
	assert workspace_path == './random-dir'
}

fn test_resolve_options_from_args_no_show_version_flag() {
	mock_args := []string
	assert resolve_options_from_args(mock_args).show_version == false
}

fn test_resolve_options_from_args_show_version_long_flag() {
	mock_args := ["--version"]
	assert resolve_options_from_args(mock_args).show_version
}

fn test_resolve_options_from_args_show_version_short_flag() {
	mock_args := ["-v"]
	assert resolve_options_from_args(mock_args).show_version
}

fn test_resolve_options_from_args_no_show_help_flag() {
	mock_args := []string
	assert resolve_options_from_args(mock_args).show_help == false
}

fn test_resolve_options_from_args_show_help_long_flag() {
	mock_args := ["--help"]
	assert resolve_options_from_args(mock_args).show_help
}

fn test_resolve_options_from_args_show_help_short_flag() {
	mock_args := ["-h"]
	assert resolve_options_from_args(mock_args).show_help

}

fn test_resolve_options_from_args_no_debug_mode_flag() {
	mock_args := []string
	assert resolve_options_from_args(mock_args).debug_mode == false
}

fn test_resolve_options_from_args_debug_mode_long_flag() {
	mock_args := ["--debug"]
	assert resolve_options_from_args(mock_args).debug_mode
}


fn test_resolve_options_from_args_debug_mode_short_flag() {

	mock_args := ["-d"]
	assert resolve_options_from_args(mock_args).debug_mode

}

