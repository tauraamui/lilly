module main

fn test_options_returns_blank_if_no_os_args() {
	options := resolve_options_from_args([])
	assert options == Options{}
}

fn test_options_matches_given_args_list_values() {
	options := resolve_options_from_args(["--debug"])
	assert options == Options{ debug_mode: true }
}
