module main

import lib.clipboard
import term.ui as tui

struct MovementKeyEventTestCase {
	name                string
	code                tui.KeyCode
	starting_cursor_pos Pos
	expected_cursor_pos Pos
}

const movement_key_cases = [
	MovementKeyEventTestCase{
		name: "key code h"
		code: tui.KeyCode.h,
		starting_cursor_pos: Pos{ x: 3, y: 0 }
		expected_cursor_pos: Pos{ x: 2, y: 0 }
	},
	MovementKeyEventTestCase{
		name: "key code l",
		code: tui.KeyCode.l,
		starting_cursor_pos: Pos{ x: 3, y: 0 }
		expected_cursor_pos: Pos{ x: 4, y: 0 }
	},
	MovementKeyEventTestCase{
		name: "key code j",
		code: tui.KeyCode.j,
		starting_cursor_pos: Pos{ x: 0, y: 0 }
		expected_cursor_pos: Pos{ x: 0, y: 1 }
	},
	MovementKeyEventTestCase{
		name: "key code k",
		code: tui.KeyCode.k,
		starting_cursor_pos: Pos{ x: 0, y: 1 }
		expected_cursor_pos: Pos{ x: 0, y: 0 }
	}
]

fn test_sets_of_key_events_for_views_on_key_down_adjusting_cursor_position() {
	for case in movement_key_cases {
		mut clip := clipboard.new()
		mut editor := Editor{ clipboard: mut clip, file_finder_modal: unsafe { nil } }
		mut fake_view := View{ log: unsafe { nil }, mode: .normal, clipboard: mut clip }
		fake_view.buffer.lines = [
			"1. first line",
			"2. second line",
			"3. third line"
		]
		fake_view.cursor.pos = case.starting_cursor_pos
		kevent := &tui.Event{ code: case.code }
		fake_view.on_key_down(kevent, mut editor)
		assert fake_view.cursor.pos == case.expected_cursor_pos, 'test case ${case.name} - expected cursor pos assertion failed'
	}
}

