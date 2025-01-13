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

fn test_buffer_insert_text() {
	mut buffer := Buffer{}
	buffer.c_buffer = GapBuffer.new("")

	for r in "Some text to insert!".runes() { buffer.c_buffer.insert(r) }

	assert buffer.str() == "Some text to insert!"
}

fn test_buffer_enter_inserts_newline_line() {
	mut buffer := Buffer{}
	buffer.c_buffer = GapBuffer.new("1. first line\n2. second line\n3. third line")
	buffer.write_at(lf, Pos{ x: 4, y: 0 })
	assert buffer.str() == "1. f\nirst line\n2. second line\n3. third line"
}
