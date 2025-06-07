module ui

fn test_cursor_check_if_line_within_selection_in_order() {
	cursor := BufferCursor{ pos: CursorPos{ x: 0, y: 3 }, sel_start_pos: CursorPos{ 0, 10 } }
	assert cursor.y_within_selection(8)
}

fn test_cursor_check_if_line_within_selection_in_order_oob() {
	cursor := BufferCursor{ pos: CursorPos{ x: 0, y: 3 }, sel_start_pos: CursorPos{ 0, 10 } }
	assert cursor.y_within_selection(24) == false
}

fn test_cursor_check_if_line_within_selection_in_reverse_order() {
	cursor := BufferCursor{ pos: CursorPos{ x: 0, y: 10 }, sel_start_pos: CursorPos{ 0, 3 } }
	assert cursor.y_within_selection(8)
}

fn test_cursor_check_if_line_within_selection_in_reverse_order_oob() {
	cursor := BufferCursor{ pos: CursorPos{ x: 0, y: 10 }, sel_start_pos: CursorPos{ 0, 3 } }
	assert cursor.y_within_selection(24) == false
}

fn test_cursor_check_start_pos_is_none_if_none() {
	cursor := BufferCursor{ pos: CursorPos{ x: 0, y: 10 } }
	assert cursor.sel_start() == none
}

fn test_cursor_check_start_pos_is_cursor_pos_if_start_is_after() {
	// start y is more than cursor y
	mut cursor := BufferCursor{ pos: CursorPos{ x: 0, y: 10 }, sel_start_pos: CursorPos{ x: 0, y: 15 } }
	assert cursor.sel_start()? == CursorPos{ x: 0, y: 10 }

	// start x is more than cursor x
	cursor = BufferCursor{ pos: CursorPos{ x: 8, y: 0 }, sel_start_pos: CursorPos{ x: 10, y: 0 } }
	assert cursor.sel_start()? == CursorPos{ x: 8, y: 0 }

	// start x and y is more than cursor x and y
	cursor = BufferCursor{ pos: CursorPos{ x: 33, y: 12 }, sel_start_pos: CursorPos{ x: 57, y: 44 } }
	assert cursor.sel_start()? == CursorPos{ x: 33, y: 12 }

	// start x is more y is the same as cursor x and y
	cursor = BufferCursor{ pos: CursorPos{ x: 33, y: 12 }, sel_start_pos: CursorPos{ x: 57, y: 12 } }
	assert cursor.sel_start()? == CursorPos{ x: 33, y: 12 }
}

fn test_cursor_check_start_pos_is_start_pos_if_cursor_is_after() {
	// cursor y is more than start y
	mut cursor := BufferCursor{ pos: CursorPos{ x: 0, y: 15 }, sel_start_pos: CursorPos{ x: 0, y: 10 } }
	assert cursor.sel_start()? == CursorPos{ x: 0, y: 10 }

	// cursor x is more than start x
	cursor = BufferCursor{ pos: CursorPos{ x: 10, y: 0 }, sel_start_pos: CursorPos{ x: 8, y: 0 } }
	assert cursor.sel_start()? == CursorPos{ x: 8, y: 0 }

	// cursor x and y is more than start x and y
	cursor = BufferCursor{ pos: CursorPos{ x: 57, y: 44 }, sel_start_pos: CursorPos{ x: 33, y: 12 } }
	assert cursor.sel_start()? == CursorPos{ x: 33, y: 12 }

	// cursor x is more y is the same as start x and y
	cursor = BufferCursor{ pos: CursorPos{ x: 57, y: 44 }, sel_start_pos: CursorPos{ x: 33, y: 44 } }
	assert cursor.sel_start()? == CursorPos{ x: 33, y: 44 }
}

