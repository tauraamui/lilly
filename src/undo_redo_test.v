module main

import datatypes

fn test_undo_redo_history_inits() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.buffer.lines = ["1. first line with an unfinished"]

	fake_view.i()

	fake_view.buffer.lines = ["1. first line with an unfinished sentence"]

	fake_view.escape()

	assert fake_view.buffer.history.stack == datatypes.Queue[Modification]{}
}

fn test_build_map_of_files() {
	old := ["1. first line has", "2. old line still here"]
	new := ["1. first line has an unfinished sentence.", "2. old line still here", "3. a brand new line!"]

	build_map_of_files(old, new)

	assert 1 == 2
}

