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
	assert cursor.sel_start()? == CursorPos{}
}

