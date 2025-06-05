module ui

pub struct CursorPos {
mut:
	x int
	y int
}

struct BufferCursor {
mut:
	pos                 CursorPos
	selection_start_pos CursorPos
}

fn (cursor BufferCursor) line_is_within_selection(line_y int) bool {
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

fn (cursor BufferCursor) selection_start() Pos {
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

fn (cursor BufferCursor) selection_end() Pos {
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

fn (cursor BufferCursor) selection_active() bool {
	return cursor.selection_start_pos.x >= 0 && cursor.selection_start_pos.y >= 0
}

