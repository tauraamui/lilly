module ui

pub struct CursorPos {
pub mut:
	x int
	y int
}

pub struct BufferCursor {
mut:
	sel_start_pos       ?CursorPos
pub mut:
	selection_start_pos CursorPos
	pos                 CursorPos
}

pub fn (cursor BufferCursor) y_within_selection(line_y int) bool {
	if sel_pos := cursor.sel_start_pos {
		// NOTE(tauraamui) [06/06/2025]: need to write a style guide for this project one day
		//                               as I seem to have invented a bunch of custom practices
		//                               for writing V code which I know is at odds with the standard
		//                               but anyway, even though technically this could be an if statement
		//                               I am finding I always much much prefer making it a match if it is
		//                               being used as an assignment result
		start := match true { sel_pos.y < cursor.pos.y { sel_pos.y } else { cursor.pos.y } }
		end   := match true { cursor.pos.y > sel_pos.y { cursor.pos.y } else { sel_pos.y } }
		return line_y >= start && line_y <= end
	}
	return false
}

pub fn (cursor BufferCursor) line_is_within_selection(line_y int) bool {
	start := if cursor.selection_start_pos.y < cursor.pos.y {
		cursor.selection_start_pos.y
	} else {
		cursor.pos.y
	}
	end := if cursor.pos.y > cursor.selection_start_pos.y {
		cursor.pos.y
	} else {
		cursor.selection_start_pos.y
	}

	return line_y >= start && line_y <= end
}

pub fn (cursor BufferCursor) sel_start() ?CursorPos {
	return ?CursorPos(none)
}

pub fn (cursor BufferCursor) selection_start() CursorPos {
	if cursor.selection_start_pos.y == cursor.pos.y {
		if cursor.selection_start_pos.x == cursor.pos.x {
			return cursor.selection_start_pos
		}
		if cursor.selection_start_pos.x < cursor.pos.x {
			return cursor.selection_start_pos
		}
		return cursor.pos
	}
	if cursor.selection_start_pos.y < cursor.pos.y {
		return cursor.selection_start_pos
	} else {
		return cursor.pos
	}
}

pub fn (cursor BufferCursor) sel_end() ?CursorPos {
	return ?CursorPos(none)
}

pub fn (cursor BufferCursor) selection_end() CursorPos {
	if cursor.pos.y == cursor.selection_start_pos.y {
		if cursor.pos.x == cursor.selection_start_pos.x {
			return cursor.pos
		}
		if cursor.pos.x > cursor.selection_start_pos.x {
			return cursor.pos
		}
		return cursor.selection_start_pos
	}
	if cursor.pos.y > cursor.selection_start_pos.y {
		return cursor.pos
	} else {
		return cursor.selection_start_pos
	}
}

pub fn (cursor BufferCursor) selection_active() bool {
	return false
}

pub fn (mut cursor BufferCursor) set_selection(sel CursorPos) {
	cursor.sel_start_pos = sel
}

pub fn (mut cursor BufferCursor) clear_selection() {
	cursor.sel_start_pos = ?CursorPos(none)
}

