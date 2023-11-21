module lib

fn test_buffer_snapshot() {
	mut buff := Buffer{
		lines: ["1. first line which already exists"]
	}

	buff.snapshot()

	assert buff.lines_cpy == buff.lines
}

fn test_buffer_update_undo_history_with_no_snapshot() {
	mut buff := Buffer{
		lines: ["1. first line which already exists"]
	}

	buff.update_undo_history()

	buff.undo()

	assert buff.lines == ["1. first line which already exists"]
}

// TODO(tauraamui): these tests will be re-worked once the undo system has been changed/re-worked
fn test_buffer_undo_some_line_insertions() {
	mut buff := Buffer{
		lines: ["1. first line which already exists"]
	}

	buff.snapshot()

	buff.lines << "2. new second line which wasn't here before snapshot!"
	assert buff.lines == [
		"1. first line which already exists",
		"2. new second line which wasn't here before snapshot!"
	]

	buff.update_undo_history()

	buff.undo()

//	assert buff.lines == ["1. first line which already exists"]
}
