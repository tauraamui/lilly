module ui

fn test_cursor_check_if_line_within_selection() {
	cursor := BufferCursor{ pos: CursorPos{ x: 0, y: 10 } }
	assert cursor.selection_active() == false
}

