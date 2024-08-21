module main

fn test_options_matches_given_args_list_values() {
	options := resolve_options_from_args(['--debug'])
	assert options.debug_mode
}
