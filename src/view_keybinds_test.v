module main

import lib.clipboard
import term.ui as tui

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
