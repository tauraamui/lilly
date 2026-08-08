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
import lib.nanoid

// apply_motion runs a navigation motion against the controller. It returns
// true if the motion key was recognised. Operators in both normal and visual
// mode share this but visual mode reuses it as "extend selection" because the
// selection range is derived from visual_sel_start + cursor.
fn apply_motion(c &documents.Controller2, doc_id nanoid.ID, motion string, count int) bool {
	match motion {
		'h' {
			for _ in 0 .. count {
				c.move_cursor_left(doc_id)
			}
		}
		'j' {
			for _ in 0 .. count {
				c.move_cursor_down(doc_id)
			}
		}
		'k' {
			for _ in 0 .. count {
				c.move_cursor_up(doc_id)
			}
		}
		'l' {
			for _ in 0 .. count {
				c.move_cursor_right(doc_id)
			}
		}
		'{' {
			for _ in 0 .. count {
				c.move_cursor_to_previous_blank_line(doc_id)
			}
		}
		'}' {
			for _ in 0 .. count {
				c.move_cursor_to_next_blank_line(doc_id)
			}
		}
		'w' {
			for _ in 0 .. count {
				c.move_cursor_to_next_word_start(doc_id)
			}
		}
		'W' {
			for _ in 0 .. count {
				c.move_cursor_to_next_big_word_start(doc_id)
			}
		}
		'e' {
			for _ in 0 .. count {
				c.move_cursor_to_next_word_end(doc_id)
			}
		}
		'b' {
			for _ in 0 .. count {
				c.move_cursor_to_previous_word_start(doc_id)
			}
		}
		'ge' {
			for _ in 0 .. count {
				c.move_cursor_to_previous_word_end(doc_id)
			}
		}
		'0' {
			c.jump_cursor_to_line_start(doc_id)
		}
		'^' {
			c.jump_cursor_to_text_start(doc_id)
		}
		'gg' {
			// bare `gg` and `1gg` both land on the first line - no ambiguity
			// since target is count-1 either way.
			target := if count > 1 { u64(count - 1) } else { u64(0) }
			c.jump_cursor_to_line(doc_id, target)
		}
		'G' {
			// bare `G` goes to the last line; an explicit count goes to that
			// line number instead (matches the `count > 1` convention `zz`
			// already uses in v1 to detect an explicit count).
			line_count := c.line_count(doc_id)
			target := if count > 1 {
				u64(count - 1)
			} else if line_count > 0 {
				line_count - 1
			} else {
				u64(0)
			}
			c.jump_cursor_to_line(doc_id, target)
		}
		'$' {
			// count works like Neovim's $: go (count-1) lines down first,
			// then to the end of that line - it does not mean "jump to
			// end of line, count times".
			for _ in 0 .. count - 1 {
				c.move_cursor_down(doc_id)
			}
			// jump_cursor_to_line_end lands one past the last character
			// (it doubles as the insert-position used by `o`); normal-mode
			// $ instead sits on the last character itself, same as h/l.
			c.jump_cursor_to_line_end(doc_id)
			_, col := c.cursor_line_and_x(doc_id)
			if col > 0 {
				c.move_cursor_left(doc_id)
			}
		}
		else {
			return false
		}
	}

	return true
}

// motion_is_inclusive reports whether an operator's range should include the
// character under the cursor at the motion's endpoint. In Neovim most
// motions are exclusive (the endpoint char is left out, e.g. `dw`); `$` is
// one of the handful that are inclusive, so `d$` deletes through the last
// character of the line rather than stopping just short of it.
fn motion_is_inclusive(motion string) bool {
	return match motion {
		'$' { true }
		else { false }
	}
}

// motion_range resolves a motion to the range it traverses, leaving the
// cursor at the motion's endpoint. Used by normal mode when an operator
// is paired with a motion (e.g. `dw`).
fn motion_range(c &documents.Controller2, doc_id nanoid.ID, motion string, count int) ?cursor.Range {
	start_line, start_col := c.cursor_line_and_x(doc_id)
	if !apply_motion(c, doc_id, motion, count) {
		return none
	}
	end_line, end_col := c.cursor_line_and_x(doc_id)
	mut end_x := int(end_col)
	if motion_is_inclusive(motion) {
		end_x += 1
	}
	return cursor.Range{
		start: cursor.Pos.new(int(start_col), int(start_line))
		end:   cursor.Pos.new(end_x, int(end_line))
	}
}

// apply_operator dispatches an operator against a resolved range. Returns
// true if the operator was recognised.
fn apply_operator(c &documents.Controller2, doc_id nanoid.ID, op u8, r cursor.Range) bool {
	match op {
		`d` {
			c.delete_range(doc_id, r)
			return true
		}
		// TODO(tauraamui) [2026-06-08]: wire up once Controller2 grows
		// change / yank etc.
		`c` {
			return false
		}
		`y` {
			return false
		}
		else {
			return false
		}
	}
}
