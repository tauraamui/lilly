// Copyright 2026 The Lilly Edtior contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

module main

import lib.documents
import lib.documents.cursor

// apply_motion runs a navigation motion against the controller. It returns
// true if the motion key was recognised. Operators in both normal and visual
// mode share this — visual mode reuses it as "extend selection" because the
// selection range is derived from visual_sel_start + cursor.
fn apply_motion(c &documents.Controller2, doc_id int, motion string, count int) bool {
	match motion {
		'h' { for _ in 0 .. count { c.move_cursor_left(doc_id) } }
		'j' { for _ in 0 .. count { c.move_cursor_down(doc_id) } }
		'k' { for _ in 0 .. count { c.move_cursor_up(doc_id) } }
		'l' { for _ in 0 .. count { c.move_cursor_right(doc_id) } }
		'{' { for _ in 0 .. count { c.move_cursor_to_previous_blank_line(doc_id) } }
		'}' { for _ in 0 .. count { c.move_cursor_to_next_blank_line(doc_id) } }
		'w' { for _ in 0 .. count { c.move_cursor_to_next_word_start(doc_id) } }
		'W' { for _ in 0 .. count { c.move_cursor_to_next_big_word_start(doc_id) } }
		'e' { for _ in 0 .. count { c.move_cursor_to_next_word_end(doc_id) } }
		'b' { for _ in 0 .. count { c.move_cursor_to_previous_word_start(doc_id) } }
		'ge' { for _ in 0 .. count { c.move_cursor_to_previous_word_end(doc_id) } }
		else { return false }
	}
	return true
}

// motion_range resolves a motion to the range it traverses, leaving the
// cursor at the motion's endpoint. Used by normal mode when an operator
// is paired with a motion (e.g. `dw`).
fn motion_range(c &documents.Controller2, doc_id int, motion string, count int) ?cursor.Range {
	start_line, start_col := c.cursor_line_and_x(doc_id)
	if !apply_motion(c, doc_id, motion, count) {
		return none
	}
	end_line, end_col := c.cursor_line_and_x(doc_id)
	return cursor.Range{
		start: cursor.Pos.new(int(start_col), int(start_line))
		end:   cursor.Pos.new(int(end_col), int(end_line))
	}
}

// apply_operator dispatches an operator against a resolved range. Returns
// true if the operator was recognised.
fn apply_operator(c &documents.Controller2, doc_id int, op u8, r cursor.Range) bool {
	match op {
		// TODO(tauraamui) [2026-06-08]: wire up once Controller2 grows
		// delete_visual_range / delete_range / yank etc.
		`d` { return false }
		`c` { return false }
		`y` { return false }
		else { return false }
	}
}
