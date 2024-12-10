module buffer

fn test_buffer_load_from_path() {
	read_lines := fn (path string) ![]string {
		return ["1. This is a first line", "2. This is a second line", "3. This is a third line"]
	}

	mut buffer := Buffer{}
	buffer.load_from_path(read_lines, false)!

	assert buffer.lines == ["1. This is a first line", "2. This is a second line", "3. This is a third line"]
}

fn test_buffer_load_from_path_use_gap_buffer() {
	read_lines := fn (path string) ![]string {
		return ["1. This is a first line", "2. This is a second line", "3. This is a third line"]
	}

	mut buffer := Buffer{}
	buffer.load_from_path(read_lines, true)!

	assert buffer.lines == ["1. This is a first line", "2. This is a second line", "3. This is a third line"]

	for _, line in buffer.gap_buffer_iterator() or { return } {
		println("LINE: ${line}")
	}

	assert 12 == 30
}
