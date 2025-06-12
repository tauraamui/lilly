module ui

fn test_cursor_resolve_line_selection_span_if_visual_line_and_y_in_selection_x_zeroed_out() {
	cursor := BufferCursor{ pos: CursorPos{ x: 0, y: 3 }, sel_start_pos: CursorPos{ 0, 10 } }
	assert cursor.resolve_line_selection_span(.visual_line, 30, 5) == SelectionSpan{ full: true }
}

fn test_cursor_resolve_line_selection_span_if_visual_line_and_y_not_in_selection_x_zeroed_out() {
	cursor := BufferCursor{ pos: CursorPos{ x: 0, y: 3 }, sel_start_pos: CursorPos{ 0, 10 } }
	assert cursor.resolve_line_selection_span(.visual_line, 30, 25) == SelectionSpan{ full: false }
}

fn test_cursor_resolve_line_selection_span_if_visual_line_and_y_in_selection_start_x_end_x_not_floored() {
	cursor := BufferCursor{ pos: CursorPos{ x: 10, y: 3 }, sel_start_pos: CursorPos{ 25, 10 } }
	assert cursor.resolve_line_selection_span(.visual_line, 30, 4) == SelectionSpan{ full: true }
}

fn test_cursor_resolve_line_selection_span_if_visual_line_and_y_not_in_selection_start_x_end_x_not_floored() {
	cursor := BufferCursor{ pos: CursorPos{ x: 10, y: 3 }, sel_start_pos: CursorPos{ 25, 10 } }
	assert cursor.resolve_line_selection_span(.visual_line, 30, 2) == SelectionSpan{ full: false }
}

fn test_cursor_resolve_line_selection_span_if_visual_and_y_in_selection_start_x_end_x_not_floored() {
	mut cursor := BufferCursor{ pos: CursorPos{ x: 10, y: 3 }, sel_start_pos: CursorPos{ 25, 10 } }
	assert cursor.resolve_line_selection_span(.visual, 30, 3) == SelectionSpan{ min_x: 10, max_x: 30, full: false }

	// this selection span is for the full line as the requested y is neither the first or last lines
	cursor = BufferCursor{ pos: CursorPos{ x: 10, y: 3 }, sel_start_pos: CursorPos{ x: 25, y: 10 } }
	assert cursor.resolve_line_selection_span(.visual, 30, 8) == SelectionSpan{ min_x: 0, max_x: 30, full: true }

	// the selection span has a clamped max as the line y is the last line of the selection
	cursor = BufferCursor{ pos: CursorPos{ x: 10, y: 3 }, sel_start_pos: CursorPos{ x: 25, y: 10 } }
	assert cursor.resolve_line_selection_span(.visual, 30, 10) == SelectionSpan{ min_x: 0, max_x: 25, full: false }
}

fn test_cursor_resolve_line_selection_span_if_visual_and_y_in_selection_starts_ends_on_same_line() {
	mut cursor := BufferCursor{ pos: CursorPos{ x: 20, y: 3 }, sel_start_pos: CursorPos{ 10, 3 } }
	assert cursor.resolve_line_selection_span(.visual, 30, 3) == SelectionSpan{ min_x: 10, max_x: 20, full: false }
}

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

fn test_selection_start_smallest_wins() {
	mut cursor := ui.BufferCursor{ pos: CursorPos{ x: 0, y: 11 }, sel_start_pos: CursorPos{ x: 4, y: 3 } }
	assert cursor.sel_start()? == CursorPos{4, 3}
}

fn test_selection_start_smallest_wins_using_method_to_set_selection() {
	mut cursor := ui.BufferCursor{ pos: CursorPos{ x: 0, y: 11 } }
	cursor.set_selection(CursorPos{ x: 4, y: 3 })
	assert cursor.sel_start()? == CursorPos{4, 3}
}

@[assert_continues]
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

@[assert_continues]
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

@[assert_continues]
fn test_cursor_check_end_pos_is_cursor_pos_if_start_is_after() {
	// start y is more than cursor y
	mut cursor := BufferCursor{ pos: CursorPos{ x: 0, y: 10 }, sel_start_pos: CursorPos{ x: 0, y: 15 } }
	assert cursor.sel_end()? == CursorPos{ x: 0, y: 15 }

	// start x is more than cursor x
	cursor = BufferCursor{ pos: CursorPos{ x: 8, y: 0 }, sel_start_pos: CursorPos{ x: 10, y: 0 } }
	assert cursor.sel_end()? == CursorPos{ x: 10, y: 0 }

	// start x and y is more than cursor x and y
	cursor = BufferCursor{ pos: CursorPos{ x: 33, y: 12 }, sel_start_pos: CursorPos{ x: 57, y: 44 } }
	assert cursor.sel_end()? == CursorPos{ x: 57, y: 44 }

	// start x is more y is the same as cursor x and y
	cursor = BufferCursor{ pos: CursorPos{ x: 33, y: 12 }, sel_start_pos: CursorPos{ x: 57, y: 12 } }
	assert cursor.sel_end()? == CursorPos{ x: 57, y: 12 }
}

@[assert_continues]
fn test_cursor_check_end_pos_is_start_pos_if_cursor_is_after() {
	// cursor y is more than start y
	mut cursor := BufferCursor{ pos: CursorPos{ x: 0, y: 15 }, sel_start_pos: CursorPos{ x: 0, y: 10 } }
	assert cursor.sel_end()? == CursorPos{ x: 0, y: 15 }

	// cursor x is more than start x
	cursor = BufferCursor{ pos: CursorPos{ x: 10, y: 0 }, sel_start_pos: CursorPos{ x: 8, y: 0 } }
	assert cursor.sel_end()? == CursorPos{ x: 10, y: 0 }

	// cursor x and y is more than start x and y
	cursor = BufferCursor{ pos: CursorPos{ x: 57, y: 44 }, sel_start_pos: CursorPos{ x: 33, y: 12 } }
	assert cursor.sel_end()? == CursorPos{ x: 57, y: 44 }

	// cursor x is more y is the same as start x and y
	cursor = BufferCursor{ pos: CursorPos{ x: 57, y: 44 }, sel_start_pos: CursorPos{ x: 33, y: 44 } }
	assert cursor.sel_end()? == CursorPos{ x: 57, y: 44 }
}

