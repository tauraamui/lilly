module main

fn test_cmd_args_matches_given_args_list_values() {
	cmd_args := resolve_cmd_args(["./textexe"]) or { CmdArgs{} }
	assert cmd_args == CmdArgs{}
}

