module main

import lib.clipboard
import lib.draw
import term.ui as tui

struct MovementKeyEventTestCase {
	name                string
	code                tui.KeyCode
	document_contents   []string
	starting_cursor_pos Pos
	expected_cursor_pos Pos
}

const (
	basic_three_lines_doc = [
		"1. first line",
		"2. second line",
		"3. third line"
	]
	gapped_blocks_of_content_doc = [
		"fn this_is_a_function() {",
		"    1 + 1",
		"}",
		"",
		"fn this_is_a_different_function() {",
		"    3495 * 22",
		"}",
	]
)

const movement_key_cases = [
	MovementKeyEventTestCase{
		name: "key code h"
		code: tui.KeyCode.h,
		document_contents: basic_three_lines_doc
		starting_cursor_pos: Pos{ x: 3, y: 0 }
		expected_cursor_pos: Pos{ x: 2, y: 0 }
	},
	MovementKeyEventTestCase{
		name: "key code l",
		code: tui.KeyCode.l,
		document_contents: basic_three_lines_doc
		starting_cursor_pos: Pos{ x: 3, y: 0 }
		expected_cursor_pos: Pos{ x: 4, y: 0 }
	},
	MovementKeyEventTestCase{
		name: "key code j",
		code: tui.KeyCode.j,
		document_contents: basic_three_lines_doc
		starting_cursor_pos: Pos{ x: 0, y: 0 }
		expected_cursor_pos: Pos{ x: 0, y: 1 }
	},
	MovementKeyEventTestCase{
		name: "key code k",
		code: tui.KeyCode.k,
		document_contents: basic_three_lines_doc
		starting_cursor_pos: Pos{ x: 0, y: 1 }
		expected_cursor_pos: Pos{ x: 0, y: 0 }
	},
	MovementKeyEventTestCase{
		name: "key code e",
		code: tui.KeyCode.e,
		document_contents: basic_three_lines_doc
		starting_cursor_pos: Pos{ x: 1, y: 1 }
		expected_cursor_pos: Pos{ x: 8, y: 1 }
	},
	MovementKeyEventTestCase{
		name: "key code w",
		code: tui.KeyCode.w,
		document_contents: basic_three_lines_doc
		starting_cursor_pos: Pos{ x: 1, y: 1 }
		expected_cursor_pos: Pos{ x: 3, y: 1 }
	},
	MovementKeyEventTestCase{
		name: "key code w end of line to next line",
		code: tui.KeyCode.w,
		document_contents: basic_three_lines_doc
		starting_cursor_pos: Pos{ x: 12, y: 0 }
		expected_cursor_pos: Pos{ x: 0, y: 1 }
	},
	MovementKeyEventTestCase{
		name: "key code b",
		code: tui.KeyCode.b,
		document_contents: basic_three_lines_doc
		starting_cursor_pos: Pos{ x: 8, y: 1 }
		expected_cursor_pos: Pos{ x: 3, y: 1 }
	},
	MovementKeyEventTestCase{
		name: "key code left"
		code: tui.KeyCode.left,
		document_contents: basic_three_lines_doc
		starting_cursor_pos: Pos{ x: 3, y: 0 }
		expected_cursor_pos: Pos{ x: 2, y: 0 }
	},
	MovementKeyEventTestCase{
		name: "key code right",
		code: tui.KeyCode.right,
		document_contents: basic_three_lines_doc
		starting_cursor_pos: Pos{ x: 3, y: 0 }
		expected_cursor_pos: Pos{ x: 4, y: 0 }
	},
	MovementKeyEventTestCase{
		name: "key code down",
		code: tui.KeyCode.down,
		document_contents: basic_three_lines_doc
		starting_cursor_pos: Pos{ x: 0, y: 0 }
		expected_cursor_pos: Pos{ x: 0, y: 1 }
	},
	MovementKeyEventTestCase{
		name: "key code up",
		code: tui.KeyCode.up,
		document_contents: basic_three_lines_doc
		starting_cursor_pos: Pos{ x: 0, y: 1 }
		expected_cursor_pos: Pos{ x: 0, y: 0 }
	},
	MovementKeyEventTestCase{
		name: "key code caret/hat",
		code: tui.KeyCode.caret,
		document_contents: basic_three_lines_doc
		starting_cursor_pos: Pos{ x: 11, y: 0 }
		expected_cursor_pos: Pos{ x: 0, y: 0 }
	},
	MovementKeyEventTestCase{
		name: "key code dollar",
		code: tui.KeyCode.dollar,
		document_contents: basic_three_lines_doc
		starting_cursor_pos: Pos{ x: 0, y: 0 }
		expected_cursor_pos: Pos{ x: 12, y: 0 }
	},
	MovementKeyEventTestCase{
		name: "key code left curly bracket",
		code: tui.KeyCode.left_curly_bracket,
		document_contents: gapped_blocks_of_content_doc
		starting_cursor_pos: Pos{ x: 0, y: 12 }
		expected_cursor_pos: Pos{ x: 0, y: 3 }
	}
]

fn test_sets_of_key_events_for_views_on_key_down_adjusting_cursor_position() {
	for case in movement_key_cases {
		mut clip := clipboard.new()
		mut editor := Editor{ clipboard: mut clip, file_finder_modal: unsafe { nil } }
		mut fake_view := View{ log: unsafe { nil }, mode: .normal, clipboard: mut clip }
		fake_view.buffer.lines = case.document_contents
		fake_view.cursor.pos = case.starting_cursor_pos
		kevent := draw.Event{ code: case.code }
		fake_view.on_key_down(kevent, mut editor)
		assert fake_view.cursor.pos == case.expected_cursor_pos, 'test case ${case.name} - expected cursor pos assertion failed'
	}
}

fn test_w_moves_cursor_to_next_line_with_plain_comments() {
	fake_lines := [
		"// Copyright 2023 The Lilly Editor contributors",
		"//",
		"// Licensed under the Apache License, Version 2.0 (the \"License\")"
	]

	mut clip := clipboard.new()
	mut editor := Editor{ clipboard: mut clip, file_finder_modal: unsafe { nil } }
	mut fake_view := View{ log: unsafe { nil }, mode: .normal, clipboard: mut clip }
	fake_view.buffer.lines = fake_lines
	fake_view.cursor.pos = Pos{ x: 28 }
	kevent := draw.Event{ code: tui.KeyCode.w }

	fake_view.on_key_down(kevent, mut editor)
	assert fake_view.cursor.pos.x == 35

	fake_view.on_key_down(kevent, mut editor)
	assert fake_view.cursor.pos.x == 54
}

