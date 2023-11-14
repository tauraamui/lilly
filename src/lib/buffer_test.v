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
