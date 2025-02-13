// Copyright 2024 The Lilly Editor contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

module main

import lib.clipboardv2
import lib.draw
import lib.buffer
import term.ui as tui
import log

struct MockRoot {
mut:
	file_finder_open                     bool
	inactive_buffer_finder_open          bool
	close_inactive_buffer_finder_invoked bool
	close_file_finder_invoked            bool
	todo_comments_finder_open            bool
	close_todo_comments_finder_invoked   bool
	special_mode                         bool
}

fn (mut root MockRoot) open_file_finder(special_mode bool) {
	root.file_finder_open = true
	root.special_mode = special_mode
}

fn (mut root MockRoot) open_inactive_buffer_finder(special_mode bool) {
	root.inactive_buffer_finder_open = true
	root.special_mode = special_mode
}

fn (mut root MockRoot) open_todo_comments_finder() {
	root.todo_comments_finder_open = true
}

fn (mut root MockRoot) open_file(path string) ! { return }

fn (mut root MockRoot) close_file_finder() {
	root.close_file_finder_invoked = true
	root.file_finder_open = false
	root.special_mode = false
}

fn (mut root MockRoot) close_inactive_buffer_finder() {
	root.close_inactive_buffer_finder_invoked = true
	root.inactive_buffer_finder_open = false
	root.special_mode = false
}

fn (mut root MockRoot) close_todo_comments_finder() {
	root.close_todo_comments_finder_invoked = true
	root.todo_comments_finder_open = false
}

fn (mut root MockRoot) quit() ! { return }
fn (mut root MockRoot) force_quit() {}

fn test_view_keybind_key_event_of_value_leader_key_changes_mode_to_leader() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log:       log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = [] // NOTE(tauraamui) [21/01/25] can be empty just not nil

	mut m_root := MockRoot{}
	fake_view.on_key_down(
		draw.Event{
			utf8: fake_view.leader_key
		},
		mut m_root
	)

	assert fake_view.leader_state.mode == .leader

	fake_view.on_key_down(
		draw.Event{
			code: .escape
		},
		mut m_root
	)

	assert fake_view.leader_state.mode == .normal
}

fn test_view_keybind_leader_then_ff_suffix_opens_file_finder() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log:       log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = [] // NOTE(tauraamui) [21/01/25] can be empty just not nil

	mut m_root := MockRoot{}
	fake_view.on_key_down(
		draw.Event{
			utf8: fake_view.leader_key
		},
		mut m_root
	)

	assert fake_view.leader_state.mode == .leader

	fake_view.on_key_down(
		draw.Event{ code: .f }, mut m_root
	)

	assert fake_view.leader_state.mode == .leader

	fake_view.on_key_down(
		draw.Event{ code: .f }, mut m_root
	)

	assert fake_view.leader_state.mode == .normal
	assert m_root.file_finder_open
	assert m_root.special_mode == false
}

fn test_view_keybind_leader_then_xff_suffix_opens_file_finder_in_special_mode() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log:       log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = [] // NOTE(tauraamui) [21/01/25] can be empty just not nil

	mut m_root := MockRoot{}
	fake_view.on_key_down(
		draw.Event{
			utf8: fake_view.leader_key
		},
		mut m_root
	)

	assert fake_view.leader_state.mode == .leader

	fake_view.on_key_down(
		draw.Event{ code: .x }, mut m_root
	)

	fake_view.on_key_down(
		draw.Event{ code: .f }, mut m_root
	)

	assert fake_view.leader_state.mode == .leader

	fake_view.on_key_down(
		draw.Event{ code: .f }, mut m_root
	)

	assert fake_view.leader_state.mode == .normal
	assert m_root.file_finder_open
	assert m_root.special_mode == true
}

fn test_view_keybind_leader_then_fb_suffix_opens_inactive_buffer_finder() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log:       log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = [] // NOTE(tauraamui) [21/01/25] can be empty just not nil

	mut m_root := MockRoot{}
	fake_view.on_key_down(
		draw.Event{
			utf8: fake_view.leader_key
		},
		mut m_root
	)

	assert fake_view.leader_state.mode == .leader

	fake_view.on_key_down(
		draw.Event{ code: .f }, mut m_root
	)

	assert fake_view.leader_state.mode == .leader

	fake_view.on_key_down(
		draw.Event{ code: .b }, mut m_root
	)

	assert fake_view.leader_state.mode == .normal
	assert m_root.inactive_buffer_finder_open
	assert m_root.special_mode == false
}

fn test_view_keybind_leader_then_ftc_suffix_opens_todo_comments_finder() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log:       log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = [] // NOTE(tauraamui) [21/01/25] can be empty just not nil

	mut m_root := MockRoot{}
	fake_view.on_key_down(
		draw.Event{
			utf8: fake_view.leader_key
		},
		mut m_root
	)

	assert fake_view.leader_state.mode == .leader

	fake_view.on_key_down(draw.Event{ code: .f }, mut m_root)
	fake_view.on_key_down(draw.Event{ code: .t }, mut m_root)
	fake_view.on_key_down(draw.Event{ code: .c }, mut m_root)

	// assert fake_view.leader_state.mode == .normal
	assert m_root.todo_comments_finder_open
}

struct MovementKeyEventTestCase {
	disabled            bool
	name                string
	code                tui.KeyCode
	document_contents   []string
	starting_cursor_pos Pos
	expected_cursor_pos Pos
}

const basic_three_lines_doc = [
	'1. first line',
	'2. second line',
	'3. third line',
]
const lines_with_empty_between = [
	'This is a first line.',
	'',
	'This is the third line.',
]
const gapped_blocks_of_content_doc = [
	'fn this_is_a_function() {',
	'    1 + 1',
	'}',
	'',
	'fn this_is_a_different_function() {',
	'    3495 * 22',
	'}',
	'struct TypeOfSomeKind{',
]

const movement_key_cases = [
	MovementKeyEventTestCase{
		name:                'key code h'
		code:                tui.KeyCode.h
		document_contents:   basic_three_lines_doc
		starting_cursor_pos: Pos{
			x: 3
			y: 0
		}
		expected_cursor_pos: Pos{
			x: 2
			y: 0
		}
	},
	MovementKeyEventTestCase{
		name:                'key code l'
		code:                tui.KeyCode.l
		document_contents:   basic_three_lines_doc
		starting_cursor_pos: Pos{
			x: 3
			y: 0
		}
		expected_cursor_pos: Pos{
			x: 4
			y: 0
		}
	},
	MovementKeyEventTestCase{
		name:                'key code j'
		code:                tui.KeyCode.j
		document_contents:   basic_three_lines_doc
		starting_cursor_pos: Pos{
			x: 0
			y: 0
		}
		expected_cursor_pos: Pos{
			x: 0
			y: 1
		}
	},
	MovementKeyEventTestCase{
		name:                'key code k'
		code:                tui.KeyCode.k
		document_contents:   basic_three_lines_doc
		starting_cursor_pos: Pos{
			x: 0
			y: 1
		}
		expected_cursor_pos: Pos{
			x: 0
			y: 0
		}
	},
	MovementKeyEventTestCase{
		name:                'key code e'
		code:                tui.KeyCode.e
		document_contents:   basic_three_lines_doc
		starting_cursor_pos: Pos{
			x: 1
			y: 1
		}
		expected_cursor_pos: Pos{
			x: 8
			y: 1
		}
	},
	MovementKeyEventTestCase{
		name:                'key code e move to end of word on line after empty line'
		code:                tui.KeyCode.e
		document_contents:   lines_with_empty_between
		starting_cursor_pos: Pos{
			x: 0
			y: 1
		}
		expected_cursor_pos: Pos{
			x: 3
			y: 2
		}
	},
	MovementKeyEventTestCase{
		name:                'key code w'
		code:                tui.KeyCode.w
		document_contents:   basic_three_lines_doc
		starting_cursor_pos: Pos{
			x: 1
			y: 1
		}
		expected_cursor_pos: Pos{
			x: 3
			y: 1
		}
	},
	MovementKeyEventTestCase{
		name:                'key code w move to end of code line which terminates with floating single special'
		code:                tui.KeyCode.w
		document_contents:   gapped_blocks_of_content_doc
		starting_cursor_pos: Pos{
			x: 7
			y: 7
		}
		expected_cursor_pos: Pos{
			x: 21
			y: 7
		}
	},
	MovementKeyEventTestCase{
		name:                'key code w end of line to next line'
		code:                tui.KeyCode.w
		document_contents:   basic_three_lines_doc
		starting_cursor_pos: Pos{
			x: 12
			y: 0
		}
		expected_cursor_pos: Pos{
			x: 0
			y: 1
		}
	},
	MovementKeyEventTestCase{
		disabled:            true
		name:                'key code b'
		code:                tui.KeyCode.b
		document_contents:   basic_three_lines_doc
		starting_cursor_pos: Pos{
			x: 8
			y: 1
		}
		expected_cursor_pos: Pos{
			x: 3
			y: 1
		}
	},
	MovementKeyEventTestCase{
		name:                'key code left'
		code:                tui.KeyCode.left
		document_contents:   basic_three_lines_doc
		starting_cursor_pos: Pos{
			x: 3
			y: 0
		}
		expected_cursor_pos: Pos{
			x: 2
			y: 0
		}
	},
	MovementKeyEventTestCase{
		name:                'key code right'
		code:                tui.KeyCode.right
		document_contents:   basic_three_lines_doc
		starting_cursor_pos: Pos{
			x: 3
			y: 0
		}
		expected_cursor_pos: Pos{
			x: 4
			y: 0
		}
	},
	MovementKeyEventTestCase{
		name:                'key code down'
		code:                tui.KeyCode.down
		document_contents:   basic_three_lines_doc
		starting_cursor_pos: Pos{
			x: 0
			y: 0
		}
		expected_cursor_pos: Pos{
			x: 0
			y: 1
		}
	},
	MovementKeyEventTestCase{
		name:                'key code up'
		code:                tui.KeyCode.up
		document_contents:   basic_three_lines_doc
		starting_cursor_pos: Pos{
			x: 0
			y: 1
		}
		expected_cursor_pos: Pos{
			x: 0
			y: 0
		}
	},
	MovementKeyEventTestCase{
		name:                'key code caret/hat'
		code:                tui.KeyCode.caret
		document_contents:   basic_three_lines_doc
		starting_cursor_pos: Pos{
			x: 11
			y: 0
		}
		expected_cursor_pos: Pos{
			x: 0
			y: 0
		}
	},
	MovementKeyEventTestCase{
		name:                'key code dollar'
		code:                tui.KeyCode.dollar
		document_contents:   basic_three_lines_doc
		starting_cursor_pos: Pos{
			x: 0
			y: 0
		}
		expected_cursor_pos: Pos{
			x: 12
			y: 0
		}
	},
	MovementKeyEventTestCase{
		name:                'key code left curly bracket'
		code:                tui.KeyCode.left_curly_bracket
		document_contents:   gapped_blocks_of_content_doc
		starting_cursor_pos: Pos{
			x: 0
			y: 12
		}
		expected_cursor_pos: Pos{
			x: 0
			y: 3
		}
	},
]

fn test_sets_of_key_events_for_views_on_key_down_adjusting_cursor_position() {
	for case in movement_key_cases {
		if case.disabled {
			continue
		}
		mut clip := clipboardv2.new()
		mut lilly := Lilly{
			clipboard:         mut clip
			file_finder_modal: unsafe { nil }
		}
		mut fake_view := View{
			log:       log.Log{}
			leader_state: ViewLeaderState{ mode: .normal }
			clipboard: mut clip
			buffer: buffer.Buffer.new("", false)
		}
		fake_view.buffer.lines = case.document_contents
		fake_view.cursor.pos = case.starting_cursor_pos
		kevent := draw.Event{
			code: case.code
		}
		fake_view.on_key_down(kevent, mut lilly)
		assert fake_view.cursor.pos == case.expected_cursor_pos, 'test case ${case.name} - expected cursor pos assertion failed'
	}
}

fn test_w_moves_cursor_to_next_line_with_plain_comments() {
	fake_lines := [
		'// Copyright 2023 The Lilly Lilly contributors',
		'//',
		'// Licensed under the Apache License, Version 2.0 (the "License")',
	]

	mut clip := clipboardv2.new()
	mut lilly := Lilly{
		clipboard:         mut clip
		file_finder_modal: unsafe { nil }
	}
	mut fake_view := View{
		log:       log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = fake_lines
	fake_view.cursor.pos = Pos{
		x: 35
	}
	kevent := draw.Event{
		code: tui.KeyCode.w
	}

	fake_view.on_key_down(kevent, mut lilly)
	assert fake_view.cursor.pos.y == 1
	assert fake_view.cursor.pos.x == 0
}
