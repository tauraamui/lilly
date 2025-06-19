module ui

import lib.core

pub struct CursorPos {
pub mut:
	x int
	y int
}

pub struct SelectionSpan {
pub:
	min_x int
	max_x int
	full bool
}

pub struct BufferCursor {
mut:
	sel_start_pos ?CursorPos
pub mut:
	pos           CursorPos
}

// TODO(tauraamui) [11/06/2025]: make this private
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

pub fn (cursor BufferCursor) resolve_line_selection_span(mode core.Mode, line_len int, line_y int) SelectionSpan {
	return match mode {
		.visual_line {
			SelectionSpan{ full: cursor.y_within_selection(line_y) }
		}
		.visual {
			start := cursor.sel_start() or { CursorPos{} }
			end   := cursor.sel_end() or { CursorPos{} }
			should_be_considered_full_line := line_y > start.y && line_y < end.y
			min_x := if start.y == line_y { start.x } else { 0 }
			max_x := if end.y == line_y { end.x } else { line_len }
			SelectionSpan{ min_x: min_x, max_x: max_x, full: should_be_considered_full_line }
		}
		else { SelectionSpan{} }
	}
}

pub fn (cursor BufferCursor) sel_start() ?CursorPos {
	start_pos := cursor.sel_start_pos or { return none }
	if start_pos.y == cursor.pos.y {
		if start_pos.x < cursor.pos.x { return start_pos }
		return cursor.pos
	}
	if start_pos.y < cursor.pos.y { return start_pos }
	return cursor.pos
}

pub fn (cursor BufferCursor) sel_end() ?CursorPos {
	start_pos := cursor.sel_start_pos or { return none }
	if start_pos.y == cursor.pos.y {
		if start_pos.x < cursor.pos.x { return cursor.pos }
		return start_pos
	}
	if start_pos.y < cursor.pos.y { return cursor.pos }
	return start_pos
}

pub fn (cursor BufferCursor) sel_active() bool {
	return cursor.sel_start_pos != none
}

pub fn (mut cursor BufferCursor) set_selection(sel CursorPos) {
	cursor.sel_start_pos = sel
}

pub fn (mut cursor BufferCursor) clear_selection() {
	cursor.sel_start_pos = ?CursorPos(none)
}

