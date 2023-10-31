module main

fn test_run_diff() {
	run_diff(["1. first line", "2. second line", "3. third line"], ["2. second line"])
	assert 1 == 2
}
