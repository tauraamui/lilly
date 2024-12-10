module buffer

fn test_buffer_load_from_path() {
	read_lines := fn (path string) ![]string {
		return ["1. This is a first line", "2. This is a second line", "3. This is a third line"]
	}

	mut buffer := Buffer{}
	buffer.load_from_path(read_lines, false)!

	assert buffer.lines == ["1. This is a first line", "2. This is a second line", "3. This is a third line"]
}

fn test_buffer_load_from_path_and_iterate() {
	read_lines := fn (path string) ![]string {
		return ["1. This is a first line", "2. This is a second line", "3. This is a third line"]
	}

	mut buffer := Buffer{}
	buffer.load_from_path(read_lines, false)!

	assert buffer.lines == ["1. This is a first line", "2. This is a second line", "3. This is a third line"]

	mut cb_invoked_count := 0
	mut cb_invoked_ref := &cb_invoked_count
	cb := fn [mut cb_invoked_ref] (id int, line string) {
		unsafe { *cb_invoked_ref += 1 }
		match id {
			0 { assert line == "1. This is a first line" }
			1 { assert line == "2. This is a second line" }
			2 { assert line == "3. This is a third line" }
			else {}
		}
	}

	buffer.iterate(cb)

	assert cb_invoked_count == 3
}

fn test_buffer_load_from_path_with_gap_buffer_and_iterate() {
	read_lines := fn (path string) ![]string {
		return ["1. This is a first line", "2. This is a second line", "3. This is a third line"]
	}

	mut buffer := Buffer{}
	buffer.load_from_path(read_lines, true)!

	mut cb_invoked_count := 0
	mut cb_invoked_ref := &cb_invoked_count
	cb := fn [mut cb_invoked_ref] (id int, line string) {
		unsafe { *cb_invoked_ref += 1 }
		match id {
			0 { assert line == "1. This is a first line" }
			1 { assert line == "2. This is a second line" }
			2 { assert line == "3. This is a third line" }
			else {}
		}
	}


	buffer.iterate(cb)

	assert cb_invoked_count == 3
}
