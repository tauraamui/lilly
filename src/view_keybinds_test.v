module main

import lib.clipboard
import term.ui as tui

struct KeyEventTestCase {
	name                string
	code                tui.KeyCode
	expected_cursor_pos Pos
}

const cases = [
	KeyEventTestCase{
		name: "key code h"
		code: tui.KeyCode.h,
		expected_cursor_pos: Pos{ x: 0, y: 0 }
	},
	KeyEventTestCase{
		name: "key code l",
		code: tui.KeyCode.l,
		expected_cursor_pos: Pos{ x: 1, y: 0 }
	},
	KeyEventTestCase{
		name: "key code j",
		code: tui.KeyCode.j,
		expected_cursor_pos: Pos{ x: 0, y: 1 }
	}
]

fn test_sets_of_key_events_for_views_on_key_down_adjusting_cursor_position() {
	mut clip := clipboard.new()
	mut editor := Editor{ clipboard: mut clip, file_finder_modal: unsafe { nil } }
	mut fake_view := View{ log: unsafe { nil }, mode: .normal, clipboard: mut clip }
	fake_view.buffer.lines = [
		"1. first line",
		"2. second line",
		"3. third line"
	]

	for case in cases {
		kevent := &tui.Event{ code: case.code }
		fake_view.on_key_down(kevent, mut editor)
		println(case.name)
		assert fake_view.cursor.pos == case.expected_cursor_pos, 'test case ${case.name} - expected cursor pos assertion failed'

		fake_view.cursor.pos = Pos{}
	}
}

fn test_keybind_interp_from_key_code_event_h() {
	mut clip := clipboard.new()
	mut editor := Editor{ clipboard: mut clip, file_finder_modal: unsafe { nil } }
	mut fake_view := View{ log: unsafe { nil }, mode: .normal, clipboard: mut clip }
	fake_view.buffer.lines = [
		"1. first line",
		"2. second line",
		"3. third line"
	]

	kevent := &tui.Event{ code: tui.KeyCode.h }
	fake_view.on_key_down(kevent, mut editor)

	assert fake_view.cursor.pos.x == 0
}

fn test_keybind_interp_from_key_code_event_l() {
	mut clip := clipboard.new()
	mut editor := Editor{ clipboard: mut clip, file_finder_modal: unsafe { nil } }
	mut fake_view := View{ log: unsafe { nil }, mode: .normal, clipboard: mut clip }
	fake_view.buffer.lines = [
		"1. first line",
		"2. second line",
		"3. third line"
	]

	kevent := &tui.Event{ code: tui.KeyCode.l }
	fake_view.on_key_down(kevent, mut editor)

	assert fake_view.cursor.pos.x == 1
}

fn test_keybind_interp_from_key_code_event_j() {
	mut clip := clipboard.new()
	mut editor := Editor{ clipboard: mut clip, file_finder_modal: unsafe { nil } }
	mut fake_view := View{ log: unsafe { nil }, mode: .normal, clipboard: mut clip }
	fake_view.buffer.lines = [
		"1. first line",
		"2. second line",
		"3. third line"
	]

	kevent := &tui.Event{ code: tui.KeyCode.j }
	fake_view.on_key_down(kevent, mut editor)

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 1
}
