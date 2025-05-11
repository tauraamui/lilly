// Copyright 2023 The Lilly Editor contributors
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

import arrays
import lib.clipboardv2
import lib.workspace
import lib.chords
import lib.buffer
import json
import lib.draw
import lib.ui
import term.ui as tui
import log
import time

struct TestDrawer {
	draw_text_callback fn (x int, y int, text string) @[required]
	draw_rect_callback fn (x int, y int, width int, height int) @[required]
	window_height      int
}

fn (mut drawer TestDrawer) draw_text(x int, y int, text string) {
	if drawer.draw_text_callback == unsafe { nil } { return }
	drawer.draw_text_callback(x, y, text)
}

fn (mut drawer TestDrawer) write(text string) {
	time.sleep(1 * time.millisecond)
}

fn (mut drawer TestDrawer) draw_rect(x int, y int, width int, height int) {
	if drawer.draw_rect_callback == unsafe { nil } { return }
	drawer.draw_rect_callback(x, y, width, height)
}

fn (mut drawer TestDrawer) draw_point(x int, y int) {
	time.sleep(1 * time.millisecond)
}

fn (mut drawer TestDrawer) render_debug() bool { return false }
fn (mut drawer TestDrawer) set_color(c draw.Color) {}
fn (mut drawer TestDrawer) set_bg_color(c draw.Color) {}
fn (mut drawer TestDrawer) reset_color() {}
fn (mut drawer TestDrawer) reset_bg_color() {}
fn (mut drawer TestDrawer) rate_limit_draws() bool { return false }
fn (mut drawer TestDrawer) window_width() int { return 500 }
fn (mut drawer TestDrawer) window_height() int { return drawer.window_height }
fn (mut drawer TestDrawer) set_cursor_position(x int, y int) {}
fn (mut drawer TestDrawer) set_cursor_to_block() {}
fn (mut drawer TestDrawer) set_cursor_to_underline() {}
fn (mut drawer TestDrawer) set_cursor_to_vertical_bar() {}
fn (mut drawer TestDrawer) show_cursor() {}
fn (mut drawer TestDrawer) hide_cursor() {}
fn (mut drawer TestDrawer) set_style(s draw.Style) {}
fn (mut drawer TestDrawer) clear_style() {}
fn (mut drawer TestDrawer) bold() {}
fn (mut drawer TestDrawer) reset() {}
fn (mut drawer TestDrawer) clear() {}
fn (mut drawer TestDrawer) flush() {}

const example_file = 'module history\n\nimport datatypes\nimport lib.diff { Op }\n\npub struct History {\nmut:\n\tundos datatypes.Stack[Op] // will actually be type diff.Op\n\tredos datatypes.Stack[Op]\n}'

fn test_line_is_within_selection() {
	mut cursor := Cursor{
		pos:                 Pos{
			x: 0
			y: 5
		}
		selection_start_pos: Pos{
			x: 4
			y: 2
		}
	}

	assert cursor.line_is_within_selection(3)
	assert cursor.line_is_within_selection(8) == false
}

fn test_selection_start_smallest_wins_check_1() {
	mut cursor := Cursor{
		pos:                 Pos{
			x: 0
			y: 2
		}
		selection_start_pos: Pos{
			x: 4
			y: 5
		}
	}

	assert cursor.selection_start() == Pos{0, 2}
}

fn test_selection_start_smallest_wins_check_2() {
	mut cursor := Cursor{
		pos:                 Pos{
			x: 0
			y: 11
		}
		selection_start_pos: Pos{
			x: 4
			y: 3
		}
	}

	assert cursor.selection_start() == Pos{4, 3}
}

fn test_dd_deletes_current_line_at_start_of_doc() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log:       log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = ['1. first line', '2. second line', '3. third line', '4. fourth line']
	fake_view.cursor.pos.y = 0

	fake_view.d()
	fake_view.d()

	assert fake_view.buffer.lines == ['2. second line', '3. third line', '4. fourth line']
	// assert fake_view.clipboard.paste() == '1. first line'
}

fn test_dd_deletes_current_line_in_middle_of_doc() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log:       log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = ['1. first line', '2. second line', '3. third line', '4. fourth line']
	fake_view.cursor.pos.y = 2

	fake_view.d()
	fake_view.d()

	assert fake_view.buffer.lines == ['1. first line', '2. second line', '4. fourth line']
	assert fake_view.cursor.pos.y == 2
	// assert fake_view.clipboard.paste() == '3. third line'
}

fn test_dd_deletes_current_line_at_end_of_doc() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log:       log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	// manually set the "document" contents
	fake_view.buffer.lines = ['1. first line', '2. second line', '3. third line']
	// ensure the cursor is set to sit on the last line
	fake_view.cursor.pos.y = fake_view.buffer.lines.len

	// invoke dd
	fake_view.d()
	fake_view.d()

	assert fake_view.buffer.lines == ['1. first line', '2. second line']
	assert fake_view.cursor.pos.y == 1
	// assert fake_view.clipboard.paste() == '3. third line'
}

fn test_dd_deletes_current_line_and_p_reinserts_it_correctly() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log:       log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = ['1. first line', '2. second line', '3. third line', '4. forth line']
	fake_view.cursor.pos.y = 0

	fake_view.d()
	assert fake_view.leader_state.mode == .pending_delete
	fake_view.d()

	assert fake_view.buffer.lines == ['2. second line', '3. third line', '4. forth line']
	assert fake_view.clipboard.get_content() == clipboardv2.ClipboardContent{
		type: .block,
		data: "1. first line"
	}

	fake_view.p()
	assert fake_view.buffer.lines == ['2. second line', '1. first line', '3. third line', '4. forth line']
	assert fake_view.leader_state.mode == .normal
	assert fake_view.cursor.pos.y == 1
	assert fake_view.cursor.pos.x == 0
}

fn test_visual_line_select_delete_and_paste_works_correctly() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log:      log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = ['1. first line', '2. second line', '3. third line', '4. fourth line']
	fake_view.j()
	fake_view.shift_v()
	fake_view.j()
	fake_view.d()

	assert fake_view.clipboard.get_content() == clipboardv2.ClipboardContent{
		type: .block,
		data: "2. second line\n3. third line"
	}

	fake_view.p()

	assert fake_view.buffer.lines == ['1. first line', '4. fourth line', '2. second line', '3. third line']
}

fn test_visual_select_copy_and_paste_works_correctly() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log:       log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = ['This is kind of a mega line right? It is pretty long!', '2. second line', '3. third line', '4. fourth line']

	fake_view.cursor.pos.y = 0

	// move cursor along line for a bit
	fake_view.w()
	fake_view.w()
	fake_view.w()

	// visual mode
	fake_view.v()

	// select some stuff
	fake_view.e()
	fake_view.e()
	fake_view.e()
	fake_view.e()

	fake_view.y()

	fake_view.escape() // TODO(tauraamui) -> this should be redundant

	assert fake_view.clipboard.get_content() == clipboardv2.ClipboardContent{
		type: .inline
		data: "of a mega line"
	}

	fake_view.j()
	fake_view.hat()
	fake_view.e()
	fake_view.e()

	fake_view.p()
	assert fake_view.buffer.lines[1] == "2. secondof a mega line line"
}

fn test_visual_select_across_multiple_lines_copy_and_paste_works_correctly() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log:       log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = ['This is kind of a mega line right? It is pretty long!', '2. second line', '3. third line', '4. fourth line']

	fake_view.cursor.pos.y = 0

	fake_view.dollar()
	fake_view.exec(chords.Op{
		repeat: 6
		kind: .move
		direction: .word_reverse
	})

	assert fake_view.cursor.pos.x == 28

	fake_view.v()
	fake_view.j()
	fake_view.dollar()
	fake_view.exec(chords.Op{
		repeat: 2
		kind: .move
		direction: .word_end
	})
	assert fake_view.cursor.pos.y == 2
	fake_view.y()
	fake_view.escape()

	assert fake_view.clipboard.get_content() == clipboardv2.ClipboardContent{
		type: .inline
		data: "kind of a mega line right? It is pretty long!\n2. second line\n3. third"
	}
}

fn test_insert_text() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	// manually set the "document" contents
	fake_view.buffer.lines = ['1. first line', '2. second line']
	// ensure cursor is set to sit on the first line
	fake_view.cursor.pos.y = 0

	fake_view.insert_text("Random words!")

	assert fake_view.leader_state.mode == .normal
	assert fake_view.buffer.lines == ['Random words!1. first line', '2. second line']
	assert fake_view.cursor.pos.x == 13
	assert fake_view.cursor.pos.y == 0
}

fn test_o_inserts_sentance_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	// manually set the "document" contents
	fake_view.buffer.lines = ['1. first line', '2. second line']
	// ensure cursor is set to sit on the first line
	fake_view.cursor.pos.y = 0

	// invoke the 'o' command
	fake_view.o()

	assert fake_view.leader_state.mode == .insert
	assert fake_view.buffer.lines == ['1. first line', '', '2. second line']
	assert fake_view.cursor.pos.y == 1
}

fn test_o_inserts_sentance_line_end_of_document() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	// manually set the "document" contents
	fake_view.buffer.lines = ['1. first line', '2. second line']
	// ensure cursor is set to sit on the second line
	fake_view.cursor.pos.y = 1

	// invoke the 'o' command
	fake_view.o()

	assert fake_view.leader_state.mode == .insert
	assert fake_view.buffer.lines == ['1. first line', '2. second line', '']
	assert fake_view.cursor.pos.y == 2
}

fn test_o_inserts_line_and_auto_indents() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	// manually set the "document" contents
	fake_view.buffer.lines = ['	1. first line']
	// ensure cursor is set to sit on the first line
	fake_view.cursor.pos.y = 0

	// invoke the 'o' command
	fake_view.o()

	assert fake_view.leader_state.mode == .insert
	assert fake_view.buffer.lines == ['	1. first line', '	']
	assert fake_view.cursor.pos.y == 1
}

fn test_o_auto_indents_but_clears_if_nothing_added_to_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	// manually set the "document" contents
	fake_view.buffer.lines = ['	1. first line']
	// ensure cursor is set to sit on the first line
	fake_view.cursor.pos.y = 0

	// invoke the 'o' command
	fake_view.o()
	fake_view.escape()

	assert fake_view.leader_state.mode == .normal
	assert fake_view.buffer.lines == ['	1. first line', '']
	assert fake_view.cursor.pos.y == 1 // cursor y does not move to selection start pos
}

fn test_resolve_whitespace_prefix_on_line_with_text() {
	test_line := '    4 spaces precede this text'
	assert resolve_whitespace_prefix(test_line) == '    '
}

fn test_resolve_whitespace_prefix_on_line_with_no_text() {
	test_line_with_just_4_spaces := '    '
	assert resolve_whitespace_prefix(test_line_with_just_4_spaces).len == 4
}

fn test_cursor_selection_start_and_end_methods_basic_situation() {
	mut cursor := Cursor{
		pos:                 Pos{
			x: 0
			y: 0
		} // make position be at "beginning"
		selection_start_pos: Pos{
			x: 20
			y: 0
		} // make selection "end" at the "end"
	}

	assert cursor.selection_start() == Pos{0, 0}
	assert cursor.selection_end() == Pos{20, 0}
}

fn test_v_toggles_visual_mode_and_starts_selection() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	// manually set the "document" contents
	fake_view.buffer.lines = ['1. first line']

	// ensure cursor is set to sit on sort of in the middle of the first line
	fake_view.cursor.pos.y = 0
	fake_view.cursor.pos.x = 6

	// invoke the 'v' command
	fake_view.v()

	assert fake_view.leader_state.mode == .visual
	assert fake_view.cursor.selection_active()
	selection_start := fake_view.cursor.selection_start()
	assert selection_start == Pos{6, 0}
	assert fake_view.cursor.pos == selection_start

	fake_view.dollar()

	assert fake_view.cursor.selection_start() == Pos{6, 0}
	assert fake_view.cursor.selection_end() == Pos{12, 0}
}

fn test_v_toggles_visual_mode_move_selection_down_to_second_line_ensure_start_position_is_same() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	// manually set the "document" contents
	fake_view.buffer.lines = ['1. first line', '//']

	// ensure cursor is set to sit on sort of in the middle of the first line
	fake_view.cursor.pos.y = 0
	fake_view.cursor.pos.x = 6

	// invoke the 'v' command
	fake_view.v()

	assert fake_view.leader_state.mode == .visual
	assert fake_view.cursor.selection_active()
	selection_start := fake_view.cursor.selection_start()
	assert selection_start == Pos{6, 0}
	assert fake_view.cursor.pos == selection_start

	fake_view.j()

	assert fake_view.cursor.selection_start() == Pos{6, 0}
	// NOTE(tauraamui) [14/01/25] I don't understand why this is correct
	//                            according to past me, but all of the
	//                            selection stuff will be re-written soon
	//                            anyway.
	// assert fake_view.cursor.selection_end() == Pos{1, 1}
}

fn resolve_test_syntax() workspace.Syntax {
	return json.decode(workspace.Syntax, '{
        "name": "test",
        "keywords": ["for", "func", "print", "bool"],
        "literals": ["nil", "true", "false"]
    }') or {
		panic('failed to parse test syntax: ${err}')
	}
}

fn test_shift_v_toggles_visual_line_mode_and_starts_selection() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	// manually set the "document" contents
	fake_view.buffer.lines = ['1. first line']
	// ensure cursor is set to sit on sort of in the middle of the first line
	fake_view.cursor.pos.y = 0
	fake_view.cursor.pos.x = 6

	// invoke the 'shift v' command
	fake_view.shift_v()

	assert fake_view.leader_state.mode == .visual_line
	assert fake_view.cursor.selection_active()
	assert fake_view.cursor.selection_start() == Pos{6, 0}
}

struct MockContextable {
mut:
	on_draw_cb fn (x int, y int, text string)
}

fn (mockctx MockContextable) render_debug() bool { return false }

fn (mockctx MockContextable) rate_limit_draws() bool {
	return false
}

fn (mockctx MockContextable) window_width() int {
	return 0
}

fn (mockctx MockContextable) window_height() int {
	return 0
}

fn (mockctx MockContextable) set_cursor_position(x int, y int) {}

fn (mockctx MockContextable) set_cursor_to_block() {}

fn (mockctx MockContextable) set_cursor_to_underline() {}

fn (mockctx MockContextable) set_cursor_to_vertical_bar() {}

fn (mockctx MockContextable) show_cursor() {}

fn (mockctx MockContextable) hide_cursor() {}

fn (mut mockctx MockContextable) draw_text(x int, y int, text string) {
	mockctx.on_draw_cb(x, y, text)
}

fn (mockctx MockContextable) write(c string) {}

fn (mockctx MockContextable) draw_rect(x int, y int, width int, height int) {}

fn (mockctx MockContextable) draw_point(x int, y int) {}

fn (mockctx MockContextable) set_color(c draw.Color) {}

fn (mockctx MockContextable) set_bg_color(c draw.Color) {}

fn (mockctx MockContextable) revert_bg_color() {}

fn (mockctx MockContextable) reset_color() {}

fn (mockctx MockContextable) reset_bg_color() {}

fn (mockctx MockContextable) set_style(s draw.Style) {}

fn (mockctx MockContextable) clear_style() {}

fn (mockctx MockContextable) bold() {}

fn (mockctx MockContextable) reset() {}

fn (mockctx MockContextable) run() ! {}

fn (mockctx MockContextable) clear() {}

fn (mockctx MockContextable) flush() {}

struct DrawnTextRec {
	content string
	pos     Pos
}

fn test_draw_text_line_visual_selection_start_end_on_same_line() {
	mut drawn_text := []DrawnTextRec{}
	mut drawn_text_ref := &drawn_text

	mut m_ctx := MockContextable{
		on_draw_cb: fn [mut drawn_text_ref] (x int, y int, text string) {
			drawn_text_ref << DrawnTextRec{
				content: text,
				pos:     Pos{ x: x, y: y }
			}
		}
	}

	mut m_cursor := Cursor{ pos: Pos{ x: 71, y: 0 }, selection_start_pos: Pos{ x: 44, y: 0 } }
	document_line := 'This part of the text is before the selection but this part is within it, and this part is after it'
	draw_text_line_within_visual_selection(
		mut m_ctx, resolve_test_syntax(),
		m_cursor, draw.Color{ r: 10, g: 10, b: 10 },
		0, 0, 0, 0, document_line, document_line
	)

	assert drawn_text.len == 3
}

fn test_draw_text_line_within_visual_selection_start_end_on_same_line_with_tab_prefix() {
	mut drawed_text := []string{}
	mut drawed_text_ref := &drawed_text
	mut m_ctx := MockContextable{
		on_draw_cb: fn [mut drawed_text_ref] (x int, y int, text string) {
			drawed_text_ref << text
		}
	}

	mut cursor := Cursor{
		pos:                 Pos{
			x: 16
			y: 0
		}
		selection_start_pos: Pos{
			x: 4
			y: 0
		}
	}
	document_line := '\tpre_sel := line_runes[..selection_start.x]'
	draw_text_line_within_visual_selection(mut m_ctx, resolve_test_syntax(), cursor, draw.Color{
		r: 10
		g: 10
		b: 10
	}, 0, 0, 0, 0, document_line.replace('\t', ' '.repeat(4)), document_line)

	assert drawed_text.len >= 1
	assert drawed_text[0] == '    pre'
	assert drawed_text[1] == '_sel := line'
	assert drawed_text[2] == '_runes[..selection_start.x]'
}

fn test_draw_text_line_within_visual_selection_start_end_on_same_line() {
	mut drawed_text := []string{}
	mut drawed_text_ref := &drawed_text
	mut m_ctx := MockContextable{
		on_draw_cb: fn [mut drawed_text_ref] (x int, y int, text string) {
			drawed_text_ref << text
		}
	}
	cursor := Cursor{
		pos:                 Pos{
			x: 16
			y: 0
		}
		selection_start_pos: Pos{
			x: 4
			y: 0
		}
	}

	document_line := 'This is a line to draw.'
	draw_text_line_within_visual_selection(mut m_ctx, resolve_test_syntax(), cursor, draw.Color{
		r: 10
		g: 10
		b: 10
	}, 0, 0, 0, 0, document_line.replace('\t', ' '.repeat(4)), document_line)

	assert drawed_text.len >= 1
	assert drawed_text[0] == 'This'
	assert drawed_text[1] == ' is a line t'
	assert drawed_text[2] == 'o draw.'
}

fn test_draw_text_line_within_visual_selection_start_pre_line_end_post_line() {
	mut drawed_text := []string{}
	mut drawed_text_ref := &drawed_text
	mut m_ctx := MockContextable{
		on_draw_cb: fn [mut drawed_text_ref] (x int, y int, text string) {
			drawed_text_ref << text
		}
	}
	cursor := Cursor{
		pos:                 Pos{
			x: 16
			y: 2
		}
		selection_start_pos: Pos{
			x: 4
			y: 0
		}
	}

	document_line := 'This is a line to draw.'
	draw_text_line_within_visual_selection(mut m_ctx, resolve_test_syntax(), cursor, draw.Color{
		r: 10
		g: 10
		b: 10
	}, 0, 0, 1, 2, document_line.replace('\t', ' '.repeat(4)), document_line)

	assert drawed_text.len >= 1
	assert drawed_text[0] == 'This is a line to draw.'
}

fn test_draw_text_line_within_visual_selection_first_line_with_selection_end_on_second_line() {
	mut drawed_text := []string{}
	mut drawed_text_ref := &drawed_text
	mut m_ctx := MockContextable{
		on_draw_cb: fn [mut drawed_text_ref] (x int, y int, text string) {
			drawed_text_ref << text
		}
	}
	cursor := Cursor{
		pos:                 Pos{
			x: 0
			y: 1
		}
		selection_start_pos: Pos{
			x: 0
			y: 0
		}
	}

	mut document_line := 'This is a line to draw.'
	draw_text_line_within_visual_selection(mut m_ctx, resolve_test_syntax(), cursor, draw.Color{
		r: 10
		g: 10
		b: 10
	}, 0, 0, 0, 0, document_line.replace('\t', ' '.repeat(4)), document_line)

	document_line = 'This is a second line.'
	draw_text_line_within_visual_selection(mut m_ctx, resolve_test_syntax(), cursor, draw.Color{
		r: 10
		g: 10
		b: 10
	}, 0, 0, 1, 1, document_line.replace('\t', ' '.repeat(4)), document_line)

	assert drawed_text.len >= 1
	assert drawed_text[0] == 'This is a line to draw.'
	assert drawed_text[1] == 'This is a second line.'
}

struct DrawnText {
	x int
	y int
	data string
}

fn test_enter_from_start_of_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .insert }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	// manually set the "document" contents
	fake_view.buffer.lines = [
		'1. first line with some trailing content',
	]

	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 0

	fake_view.enter()

	assert fake_view.buffer.lines == [
		'',
		'1. first line with some trailing content',
	]
	assert fake_view.cursor.pos.x == 0
}

fn test_enter_moves_trailing_segment_to_next_line_and_moves_cursor_in_front() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .insert }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	// manually set the "document" contents
	fake_view.buffer.lines = [
		'1. first line with some trailing content',
	]

	fake_view.cursor.pos.x = 8
	fake_view.cursor.pos.y = 0

	fake_view.enter()

	assert fake_view.buffer.lines == [
		'1. first',
		' line with some trailing content',
	]
	assert fake_view.cursor.pos.x == 0
}

fn test_enter_moves_trailing_segment_to_next_line_and_moves_cursor_to_past_prefix_whitespace() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .insert }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = [
		'    1. first line with whitespace prefix',
	]

	fake_view.cursor.pos.x = 10
	fake_view.cursor.pos.y = 0

	fake_view.enter()

	assert fake_view.buffer.lines == [
		'    1. fir',
		'    st line with whitespace prefix',
	]
	assert fake_view.cursor.pos.x == 4
}

fn test_enter_inserts_line_at_cur_pos_and_auto_indents() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .insert }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	// manually set the "document" contents
	fake_view.buffer.lines = ['	indented first line']
	// ensure cursor is set to sit on the first line
	fake_view.cursor.pos.y = 0
	// ensure cursor is set to sit on the end of the line
	fake_view.cursor.pos.x = fake_view.buffer.lines[fake_view.cursor.pos.y].len

	// invoke enter
	fake_view.enter()

	assert fake_view.buffer.lines == ['	indented first line', '	']
}

fn test_enter_auto_indents_but_clears_if_nothing_added_to_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .insert }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	// manually set the "document" contents
	fake_view.buffer.lines = ['	indented first line']
	// ensure cursor is set to sit on the first line
	fake_view.cursor.pos.y = 0
	// ensure cursor is set to sit on the end of the line
	fake_view.cursor.pos.x = fake_view.buffer.lines[fake_view.cursor.pos.y].len

	// invoke enter
	fake_view.enter()
	assert fake_view.buffer.lines == ['	indented first line', '	']

	fake_view.enter()
	assert fake_view.buffer.lines == ['	indented first line', '', '']
}

fn test_backspace_deletes_char_from_end_of_sentance() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	// manually set the "document" contents
	fake_view.buffer.lines = ['single line of text!']
	// ensure cursor is set to sit on the first line
	fake_view.cursor.pos.y = 0
	fake_view.leader_state.mode = .insert
	fake_view.cursor.pos.x = fake_view.buffer.lines[fake_view.cursor.pos.y].len

	// invoke backspace
	fake_view.backspace()
	assert fake_view.buffer.lines == ['single line of text']

	// invoke backspace
	fake_view.backspace()
	assert fake_view.buffer.lines == ['single line of tex']
}

fn test_backspace_deletes_char_from_start_of_sentance() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.leader_state.mode = .insert

	// manually set the "document" contents
	fake_view.buffer.lines = ['', 'single line of text!']
	// ensure cursor is set to sit on the second line
	fake_view.cursor.pos.y = 1
	// ensure the cursor is set to sit on the second char of the line
	fake_view.cursor.pos.x = 1

	// invoke backspace
	fake_view.backspace()
	assert fake_view.buffer.lines == ['', 'ingle line of text!']
}

fn test_backspace_moves_line_up_to_previous_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.leader_state.mode = .insert

	// manually set the document contents
	fake_view.buffer.lines = ['', 'single line of text!']
	// ensure cursor is set to sit on the second line
	fake_view.cursor.pos.y = 1
	// ensure the cursor is set to sit on the second char of the line
	fake_view.cursor.pos.x = 0

	// invoke backspace
	fake_view.backspace()
	assert fake_view.buffer.lines == ['single line of text!']
}

fn test_backspace_moves_line_up_to_end_of_previous_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.leader_state.mode = .insert

	// manually set the document contents
	fake_view.buffer.lines = ['i am the first line', 'single line of text!']
	// ensure cursor is set to sit on the second line
	fake_view.cursor.pos.y = 1
	// ensure the cursor is set to sit on the first char of the line
	fake_view.cursor.pos.x = 0

	// invoke backspace
	fake_view.backspace()
	assert fake_view.buffer.lines == ['i am the first linesingle line of text!']
	assert fake_view.cursor.pos.x == 19
	assert fake_view.cursor.pos.y == 0
	assert fake_view.buffer.lines[fake_view.cursor.pos.y][fake_view.cursor.pos.x].ascii_str() == 's'
}

fn test_backspace_at_start_of_sentance_first_line_does_nothing() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.leader_state.mode = .insert

	// manually set the document contents
	fake_view.buffer.lines = ['single line of text!', '']
	// ensure cursor is set to sit on the first line
	fake_view.cursor.pos.y = 0
	// ensure cursor is set to sit on the first char of the line
	fake_view.cursor.pos.x = 0

	// invoke backspace
	fake_view.backspace()
	assert fake_view.buffer.lines == ['single line of text!', '']
}

fn test_move_cursor_left_with_h_proceeds_to_start_of_line() {
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: clipboardv2.new()
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = ['1. first line']

	fake_view.cursor.pos.x = 9
	fake_view.cursor.pos.y = 0

	fake_view.h()

	assert fake_view.cursor.pos.x == 8
	assert fake_view.cursor.pos.y == 0

	fake_view.h()

	assert fake_view.cursor.pos.x == 7
	assert fake_view.cursor.pos.y == 0

	for _ in 0..7 { fake_view.h() }

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 0

	fake_view.h()

	// ensure cursor within document bounds
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 0

}

fn test_move_cursor_right_with_l_proceeds_to_end_of_line() {
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: clipboardv2.new()
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = ['1. first line']

	fake_view.cursor.pos.x = 5
	fake_view.cursor.pos.y = 0

	fake_view.l()

	assert fake_view.cursor.pos.x == 6
	assert fake_view.cursor.pos.y == 0

	fake_view.l()

	assert fake_view.cursor.pos.x == 7
	assert fake_view.cursor.pos.y == 0

	for _ in 0..5 { fake_view.l() }

	assert fake_view.cursor.pos.x == 12
	assert fake_view.cursor.pos.y == 0

	fake_view.l()

	// ensure cursor within document bounds
	assert fake_view.cursor.pos.x == 12
	assert fake_view.cursor.pos.y == 0
}

fn test_move_cursor_down_with_j_proceeds_to_next_line_with_x_maxed() {
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: clipboardv2.new()
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = [
		'1. first line with five words',
		'2. second line with five words',
		'3. third line with five words',
		'4. forth line with five words',
		'5. fifth line with five words',
	]

	fake_view.cursor.pos.x = 5
	fake_view.cursor.pos.y = 0

	fake_view.j()

	assert fake_view.cursor.pos.x == 5
	assert fake_view.cursor.pos.y == 1

	fake_view.j()

	assert fake_view.cursor.pos.x == 5
	assert fake_view.cursor.pos.y == 2

	for _ in 0..2 { fake_view.j() }

	assert fake_view.cursor.pos.x == 5
	assert fake_view.cursor.pos.y == 4

	fake_view.j()

	// ensure cursor within document bounds
	assert fake_view.cursor.pos.x == 5
	assert fake_view.cursor.pos.y == 4
}

fn test_move_cursor_up_with_k_proceeds_to_previous_line_with_x_maxed() {
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: clipboardv2.new()
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = [
		'1. first line with five words',
		'2. second line with five words',
		'3. third line with five words',
		'4. forth line with five words',
		'5. fifth line with five words',
	]

	fake_view.cursor.pos.x = 5
	fake_view.cursor.pos.y = 4

	fake_view.k()

	assert fake_view.cursor.pos.x == 5
	assert fake_view.cursor.pos.y == 3

	fake_view.k()

	assert fake_view.cursor.pos.x == 5
	assert fake_view.cursor.pos.y == 2

	for _ in 0..2 { fake_view.k() }

	assert fake_view.cursor.pos.x == 5
	assert fake_view.cursor.pos.y == 0

	fake_view.k()

	// ensure cursor within document bounds
	assert fake_view.cursor.pos.x == 5
	assert fake_view.cursor.pos.y == 0
}

fn test_move_cursor_left_with_left_proceeds_to_start_of_line() {
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: clipboardv2.new()
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = ['1. first line']

	fake_view.cursor.pos.x = 9
	fake_view.cursor.pos.y = 0

	fake_view.left()

	assert fake_view.cursor.pos.x == 8
	assert fake_view.cursor.pos.y == 0

	fake_view.left()

	assert fake_view.cursor.pos.x == 7
	assert fake_view.cursor.pos.y == 0

	for _ in 0..7 { fake_view.left() }

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 0

	fake_view.left()

	// ensure cursor within document bounds
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 0

}

fn test_move_cursor_right_with_right_proceeds_to_end_of_line() {
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: clipboardv2.new()
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = ['1. first line']

	fake_view.cursor.pos.x = 5
	fake_view.cursor.pos.y = 0

	fake_view.right()

	assert fake_view.cursor.pos.x == 6
	assert fake_view.cursor.pos.y == 0

	fake_view.right()

	assert fake_view.cursor.pos.x == 7
	assert fake_view.cursor.pos.y == 0

	for _ in 0..5 { fake_view.right() }

	assert fake_view.cursor.pos.x == 12
	assert fake_view.cursor.pos.y == 0

	fake_view.right()

	// ensure cursor within document bounds
	assert fake_view.cursor.pos.x == 12
	assert fake_view.cursor.pos.y == 0
}

fn test_move_cursor_down_with_down_proceeds_to_next_line_with_x_maxed() {
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: clipboardv2.new()
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = [
		'1. first line with five words',
		'2. second line with five words',
		'3. third line with five words',
		'4. forth line with five words',
		'5. fifth line with five words',
	]

	fake_view.cursor.pos.x = 5
	fake_view.cursor.pos.y = 0

	fake_view.down()

	assert fake_view.cursor.pos.x == 5
	assert fake_view.cursor.pos.y == 1

	fake_view.down()

	assert fake_view.cursor.pos.x == 5
	assert fake_view.cursor.pos.y == 2

	for _ in 0..2 { fake_view.down() }

	assert fake_view.cursor.pos.x == 5
	assert fake_view.cursor.pos.y == 4

	fake_view.down()

	// ensure cursor within document bounds
	assert fake_view.cursor.pos.x == 5
	assert fake_view.cursor.pos.y == 4
}

fn test_move_cursor_down_with_down_proceeds_to_next_line_with_x_maxed_contains_blank_lines() {
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: clipboardv2.new()
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = [
		'1. first line with five words',
		'',
		'3. third line with five words',
		'',
		'5. fifth line with five words',
	]

	fake_view.cursor.pos.x = 5
	fake_view.cursor.pos.y = 0

	fake_view.down()

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 1

	fake_view.down()

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 2

	for _ in 0..2 { fake_view.down() }

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 4

	fake_view.down()

	// ensure cursor within document bounds
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 4
}

fn test_move_cursor_up_with_up_proceeds_to_previous_line_with_x_maxed() {
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: clipboardv2.new()
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = [
		'1. first line with five words',
		'2. second line with five words',
		'3. third line with five words',
		'4. forth line with five words',
		'5. fifth line with five words',
	]

	fake_view.cursor.pos.x = 5
	fake_view.cursor.pos.y = 4

	fake_view.up()

	assert fake_view.cursor.pos.x == 5
	assert fake_view.cursor.pos.y == 3

	fake_view.up()

	assert fake_view.cursor.pos.x == 5
	assert fake_view.cursor.pos.y == 2

	for _ in 0..2 { fake_view.k() }

	assert fake_view.cursor.pos.x == 5
	assert fake_view.cursor.pos.y == 0

	fake_view.up()

	// ensure cursor within document bounds
	assert fake_view.cursor.pos.x == 5
	assert fake_view.cursor.pos.y == 0
}

fn test_move_cursor_up_with_up_proceeds_to_next_line_with_x_maxed_contains_blank_lines() {
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: clipboardv2.new()
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = [
		'1. first line with five words',
		"",
		'3. third line with five words',
		"",
		'5. fifth line with five words',
	]

	fake_view.cursor.pos.x = 5
	fake_view.cursor.pos.y = 4

	fake_view.up()

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 3

	fake_view.up()

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 2

	for _ in 0..2 { fake_view.k() }

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 0

	fake_view.up()

	// ensure cursor within document bounds
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 0
}

fn test_left_arrow_at_start_of_sentence_in_insert_mode() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.leader_state.mode = .insert

	// manually set the document contents
	fake_view.buffer.lines = ['', 'single line of text!', '']
	// ensure cursor is set to sit on the second line
	fake_view.cursor.pos.y = 1
	// ensure cursor is set to sit on the first char of the line
	fake_view.cursor.pos.x = 0

	// invoke left
	fake_view.left()

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 1 // this is desired for left move using list of lines buffer
}

fn test_left_arrow_at_end_of_sentence_in_insert_mode() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.leader_state.mode = .insert

	// manually set the documents contents
	fake_view.buffer.lines = ['', 'single line of text!', '']
	// ensure cursor is set to sit on the second line
	fake_view.cursor.pos.y = 1
	// ensure the cursor is set to sit on the last char of the line
	fake_view.cursor.pos.x = fake_view.buffer.lines[fake_view.cursor.pos.y].len

	// invoke left
	fake_view.left()

	assert fake_view.cursor.pos.x == 19
}

fn test_right_arrow_at_start_of_sentence_in_insert_mode() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.leader_state.mode = .insert

	// manually set the documents contents
	fake_view.buffer.lines = ['', 'single line of text!', '']
	// ensure cursor is set to sit on the second line
	fake_view.cursor.pos.y = 1
	// ensure cursor is set to sit on the first char of the line
	fake_view.cursor.pos.x = 0

	// invoke right
	fake_view.right()

	assert fake_view.cursor.pos.x == 1
}

fn test_right_arrow_at_end_of_sentence_in_insert_mode() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.leader_state.mode = .insert

	// manually set the documents contents
	fake_view.buffer.lines = ['', 'single line of text!', '']
	// ensure cursor is set to sit on the second line
	fake_view.cursor.pos.y = 1
	// ensure the cursor is set to sit on the last char of the line
	fake_view.cursor.pos.x = fake_view.buffer.lines[fake_view.cursor.pos.y].len

	// invoke right
	fake_view.right()

	assert fake_view.cursor.pos.x == 20
}

fn test_right_arrow_on_empty_line_in_normal_mode() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	// fake_view.leader_state.mode = .insert

	// manually set the documents contents
	fake_view.buffer.lines = ['', 'single line of text!', '']
	// ensure cursor is set to sit on the second line
	fake_view.cursor.pos.y = 0
	// ensure the cursor is set to sit on the last char of the line
	fake_view.cursor.pos.x = 0

	// invoke right
	fake_view.right()

	assert fake_view.cursor.pos.x == 0
}

fn test_tab_inserts_spaces() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .insert }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	// manually set the documents contents
	fake_view.buffer.lines = ['1. first line']

	fake_view.cursor.pos.x = 9
	fake_view.cursor.pos.y = 0

	fake_view.insert_tab()

	assert fake_view.leader_state.mode == .insert
	assert fake_view.buffer.lines == ['1. first     line']

	assert fake_view.cursor.pos.x == 13
	assert fake_view.cursor.pos.y == 0
}

fn test_tab_inserts_tabs_not_spaces_if_enabled() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .insert }
		clipboard: mut clip
		config:    workspace.Config{
			insert_tabs_not_spaces: true
		}
		buffer: buffer.Buffer.new("", false)
	}

	// manually set the documents contents
	fake_view.buffer.lines = ['1. first line']

	fake_view.cursor.pos.x = 9
	fake_view.cursor.pos.y = 0

	fake_view.insert_tab()

	assert fake_view.leader_state.mode == .insert
	assert fake_view.buffer.lines == ['1. first \tline']

	assert fake_view.cursor.pos.x == 10
	assert fake_view.cursor.pos.y == 0
}

fn test_visual_indent_indents_highlighted_lines() {
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .visual }
		clipboard: clipboardv2.new()
		config:    workspace.Config{
			insert_tabs_not_spaces: true
		}
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.buffer.lines = [
		'1. first line',
		'2. second line',
		'3. third line',
		'4. fourth line',
		'5. fifth line',
		'6. sixth line',
	]

	fake_view.cursor.pos.y = 1

	fake_view.shift_v()
	fake_view.j()
	fake_view.j()
	fake_view.j()

	fake_view.visual_indent()

	assert fake_view.buffer.lines == [
		'1. first line',
		'\t2. second line',
		'\t3. third line',
		'\t4. fourth line',
		'\t5. fifth line',
		'6. sixth line',
	]
}

fn test_visual_unindent_unindents_highlighted_lines() {
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .visual_line }
		clipboard: clipboardv2.new()
		config:    workspace.Config{
			insert_tabs_not_spaces: true
		}
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.buffer.lines = [
		'1. first line',
		'\t2. second line',
		'\t3. third line',
		'\t4. fourth line',
		'\t5. fifth line',
		'6. sixth line',
	]

	fake_view.cursor.pos.y = 1

	fake_view.shift_v()
	fake_view.j()
	fake_view.j()
	fake_view.j()

	fake_view.visual_unindent()

	assert fake_view.buffer.lines == [
		'1. first line',
		'2. second line',
		'3. third line',
		'4. fourth line',
		'5. fifth line',
		'6. sixth line',
	]
}

fn test_visual_insert_mode_and_delete_in_place() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	// manually set the documents contents
	fake_view.buffer.lines = ['1. first line', '2. second line', '3. third line', '4. fourth line']
	// ensure cursor is set to sit on the start of second line
	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 1

	fake_view.shift_v()
	fake_view.visual_line_d(true)

	assert fake_view.leader_state.mode == .normal
	assert fake_view.buffer.lines == ['1. first line', '3. third line', '4. fourth line']
}

fn test_visual_insert_mode_selection_move_down_once_and_delete() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	// manually set the documents contents
	fake_view.buffer.lines = ['1. first line', '2. second line', '3. third line', '4. fourth line']
	// ensure cursor is set to sit on the start of second line
	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 1

	fake_view.shift_v()
	fake_view.j()
	fake_view.visual_line_d(true)

	assert fake_view.leader_state.mode == .normal
	assert fake_view.buffer.lines == ['1. first line', '4. fourth line']
}

fn test_visual_selection_copy_starts_and_ends_on_same_line_and_selects_whole_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	// manually set the documents contents
	fake_view.buffer.lines = [
		'1. first line',
		'2. second line',
		'3. third line',
		'4. fourth line',
		'5. fifth line',
	]

	// ensure cursor is set to start inside second line
	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 1

	fake_view.v()
	fake_view.dollar()
	fake_view.y()

	assert fake_view.clipboard.get_content() == clipboardv2.ClipboardContent{
		type: .inline,
		data: "2. second line"
	}
}

fn test_visual_selection_mode_escaped_leaves_cursor_in_final_position() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	// manually set the documents contents
	fake_view.buffer.lines = [
		'1. first line',
		'2. second line',
		'3. third line',
		'4. fourth line',
		'5. fifth line',
	]

	// ensure cursor is set to start inside second line
	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 1
	fake_view.shift_v()
	fake_view.j()
	fake_view.j()
	fake_view.j()
	fake_view.escape()
	assert fake_view.cursor.pos.y == 4
}

/*
fn test_visual_selection_copy_ends_on_halfway_in_on_next_line_down() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log:       unsafe { nil }
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	// manually set the documents contents
	fake_view.buffer.lines = [
		'1. first line',
		'2. second line',
		'3. third line',
		'4. fourth line',
		'5. fifth line',
	]

	// ensure cursor is set to start inside second line
	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 1

	fake_view.v()
	fake_view.j()
	fake_view.e()
	fake_view.e()
	fake_view.y()

	assert fake_view.clipboard.paste() == '2. second line\n3. third'
}

fn test_visual_selection_copy_starts_and_ends_a_few_lines_down() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log:       unsafe { nil }
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	// manually set the documents contents
	fake_view.buffer.lines = [
		'1. first line',
		'2. second line',
		'3. third line',
		'4. fourth line',
		'5. fifth line',
	]

	// ensure cursor is set to start inside second line
	fake_view.cursor.pos.x = 3
	fake_view.cursor.pos.y = 0

	fake_view.v()
	for _ in 0 .. 3 {
		fake_view.j()
	}
	fake_view.y()

	assert fake_view.clipboard.paste() == 'first line\n2. second line\n3. third line\n4. f'
}

fn test_visual_line_selection_copy() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log:       unsafe { nil }
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	// manually set the documents contents
	fake_view.buffer.lines = [
		'1. first line',
		'2. second line',
		'3. third line',
		'4. fourth line',
		'5. fifth line',
	]

	// ensure cursor is set to sit on second line
	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 1

	fake_view.shift_v()
	fake_view.j()
	fake_view.y()

	clipboard_contents := fake_view.clipboard.paste()
	assert clipboard_contents.len >= 1
	assert clipboard_contents.runes()[0] == `\n`
	assert clipboard_contents.runes()[clipboard_contents.runes().len - 1] == `\n`
	clipboard_contents_lines := clipboard_contents.split_into_lines()
	assert clipboard_contents_lines[1..] == [
		'2. second line',
		'3. third line',
	]
}

fn test_paste_segment_of_line() {
	mut clip := clipboardv2.new()
	clip.copy('new segment of a line')
	mut fake_view := View{
		log:       unsafe { nil }
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	// manually set the documents contents
	fake_view.buffer.lines = [
		'A shopping list',
		'Strawberries x 30',
		'Cheese, blue and red',
		'Blueberry smoothies',
	]

	// ensure cursor is set to sit on second line
	fake_view.cursor.pos.x = 10
	fake_view.cursor.pos.y = 1

	fake_view.p()

	assert fake_view.buffer.lines == [
		'A shopping list',
		'Strawberrinew segment of a linees x 30',
		'Cheese, blue and red',
		'Blueberry smoothies',
	]
}

fn test_paste_segment_which_does_not_start_nor_end_with_newline() {
	mut clip := clipboardv2.new()
	clip.copy('partial selection from a line\nup to some point on the next line down')
	mut fake_view := View{
		log:       unsafe { nil }
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	// manually set the documents contents
	fake_view.buffer.lines = [
		'A shopping list',
		'Strawberries x 30',
		'Cheese, blue and red',
		'Blueberry smoothies',
	]

	// ensure cursor is set to sit on second line
	fake_view.cursor.pos.x = 10
	fake_view.cursor.pos.y = 1

	fake_view.p()

	assert fake_view.buffer.lines == [
		'A shopping list',
		'Strawberripartial selection from a line',
		'up to some point on the next line downes x 30',
		'Cheese, blue and red',
		'Blueberry smoothies',
	]
}

fn test_paste_full_lines() {
	mut clip := clipboardv2.new()
	clip.set_content(clipboardv2.ClipboardContent{
		type: .block
		data: "some new random contents\nwith multiple lines"
	})
	// clip.copy('\nsome new random contents\nwith multiple lines\n')
	mut fake_view := View{
		log:       unsafe { nil }
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	// manually set the documents contents
	fake_view.buffer.lines = [
		'1. first line',
		'2. second line',
		'3. third line',
		'4. fourth line',
		'5. fifth line',
	]

	// ensure cursor is set to sit on second line
	fake_view.cursor.pos.x = 14
	fake_view.cursor.pos.y = 1

	fake_view.p()

	assert fake_view.buffer.lines == [
		'1. first line',
		'2. second line',
		'some new random contents',
		'with multiple lines',
		'3. third line',
		'4. fourth line',
		'5. fifth line',
	]
}

fn test_copying_full_lines_with_visual_line_mode_and_pasting() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log:       unsafe { nil }
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	// manually set the documents contents
	fake_view.buffer.lines = [
		'1. first line',
		'2. second line',
		'3. third line',
		'4. fourth line',
		'5. fifth line',
	]

	// ensure cursor is set to sit on second line
	fake_view.cursor.pos.x = 4
	fake_view.cursor.pos.y = 0

	fake_view.shift_v()
	fake_view.j()
	fake_view.j()
	fake_view.y()
	// assert clip.paste() == ""
	fake_view.j()
	fake_view.j()
	fake_view.j()
	fake_view.p()

	assert fake_view.buffer.lines == [
		'1. first line',
		'2. second line',
		'3. third line',
		'4. fourth line',
		'1. first line',
		'2. second line',
		'3. third line',
		'5. fifth line',
	]
}
*/

fn test_search_is_toggled() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.search()

	assert fake_view.leader_state.mode == .search
}

fn test_search_within_for_single_line() {
	mut fake_search := Search{
		to_find: '/efg'
	}
	fake_search.find(['abcdefg'])
	assert fake_search.finds[0] == [4, 7]
	result := fake_search.next_find_pos() or { panic('') }
	assert result.start == 4
	assert result.end == 7
	assert result.line == 0
}

fn test_search_within_for_single_line_resolves_matches_for_given_line() {
	mut fake_search := Search{
		to_find: '/efg'
	}
	fake_search.find(['abcdefg'])
	assert fake_search.finds[0] == [4, 7]
	result := fake_search.next_find_pos() or { panic('') }
	assert result.start == 4
	assert result.end == 7
	assert result.line == 0
	assert fake_search.get_line_matches(0) == [
		Match{
			line:  0
			start: 4
			end:   7
		},
	]
}

fn test_search_within_for_multiple_lines() {
	mut fake_search := Search{
		to_find: '/redpanda'
	}
	fake_search.find([
		"This is a fake document that doesn't talk about anything.",
		"It might mention animals like bats, redpandas and goats, but that's all.",
		'Trees are where redpandas hang out, literally.',
	])
	assert fake_search.finds[0] == []
	assert fake_search.finds[1] == [36, 44]
	assert fake_search.finds[2] == [16, 24]

	first_result := fake_search.next_find_pos() or { panic('') }
	assert first_result.start == 36
	assert first_result.end == 44
	assert first_result.line == 1

	second_result := fake_search.next_find_pos() or { panic('') }
	assert second_result.start == 16
	assert second_result.end == 24
	assert second_result.line == 2

	scrolled_back_around_result := fake_search.next_find_pos() or { panic('') }
	assert scrolled_back_around_result.start == 36
	assert scrolled_back_around_result.end == 44
	assert scrolled_back_around_result.line == 1
}

fn test_search_within_for_multiple_lines_multiple_matches_per_line() {
	mut fake_search := Search{
		to_find: '/redpanda'
	}
	fake_search.find([
		'This is a fake document about redpandas, it mentions redpandas multiple times.',
		'Any animal like redpandas might be referred to more than once, who knows?',
	])

	assert fake_search.finds[0] == [30, 38, 53, 61]
	assert fake_search.finds[1] == [16, 24]

	first_result := fake_search.next_find_pos() or { panic('') }
	assert first_result.start == 30
	assert first_result.end == 38
	assert first_result.line == 0

	second_result := fake_search.next_find_pos() or { panic('') }
	assert second_result.start == 53
	assert second_result.end == 61
	assert second_result.line == 0

	third_result := fake_search.next_find_pos() or { panic('') }
	assert third_result.start == 16
	assert third_result.end == 24
	assert third_result.line == 1

	looped_back_first_result := fake_search.next_find_pos() or { panic('') }
	assert looped_back_first_result.start == 30
	assert looped_back_first_result.end == 38
	assert looped_back_first_result.line == 0
}

fn test_move_cursor_with_b_from_start_of_line_which_preceeds_a_blank_line() {
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: clipboardv2.new()
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = ['1. first line', '', '3. third line']

	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 2

	fake_view.b()

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 1
}

fn test_jump_cursor_up_to_next_blank_line() {
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: clipboardv2.new()
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = [
		'# Top of the file',
		'',
		'Some fake block of text which may or may not be',
		'more than one line in size, so it can be used for',
		'this testing scenario.',
		'',
		'this is the last line of the document',
	]

	fake_view.cursor.pos.y = 4
	assert 'this testing scenario.' == fake_view.buffer.lines[fake_view.cursor.pos.y]
	fake_view.jump_cursor_up_to_next_blank_line()
	assert '' == fake_view.buffer.lines[fake_view.cursor.pos.y]
	fake_view.jump_cursor_up_to_next_blank_line()
	assert '# Top of the file' == fake_view.buffer.lines[fake_view.cursor.pos.y]
}

fn test_jump_cursor_down_to_next_blank_line() {
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: clipboardv2.new()
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = [
		'# Top of the file',
		'',
		'Some fake block of text which may or may not be',
		'more than one line in size, so it can be used for',
		'this testing scenario.',
		'',
		'this is the last line of the document',
	]

	fake_view.cursor.pos.y = 0
	assert '# Top of the file' == fake_view.buffer.lines[fake_view.cursor.pos.y]
	fake_view.jump_cursor_down_to_next_blank_line()
	assert '' == fake_view.buffer.lines[fake_view.cursor.pos.y]
	fake_view.jump_cursor_down_to_next_blank_line()
	assert '' == fake_view.buffer.lines[fake_view.cursor.pos.y]
	fake_view.jump_cursor_down_to_next_blank_line()
	assert 'this is the last line of the document' == fake_view.buffer.lines[fake_view.cursor.pos.y]
}

fn test_calc_w_move_end_of_line_jumps_down_to_next_line_which_is_blank() {
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: clipboardv2.new()
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = [
		'# Top of the file',
		'',
		'A line just after the blank line above it',
	]

	fake_view.cursor.pos.y = 0
	fake_view.dollar()
	fake_view.w()
}

fn test_calc_w_move_amount_simple_sentence_line() {
	// manually set the documents contents
	fake_line := 'this is a line to test with'
	mut fake_cursor_pos := Pos{
		x: 0
	}

	mut amount := calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 5
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'i'

	amount = calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 3
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'a'
}

fn test_calc_w_move_amount_beyond_repeated_sequence_of_special_char() {
	// manually set the documents contents
	fake_line := '(((#####)))'
	mut fake_cursor_pos := Pos{
		x: 0
	}
	assert fake_line[fake_cursor_pos.x].ascii_str() == '('

	mut amount := calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 3
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == '#'

	amount = calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 5
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == ')'

	amount = calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 0
}

fn test_calc_w_move_amount_to_special_char_before_next_word_past_space() {
	// manually set the documents contents
	fake_line := 'fn function_name() int'
	mut fake_cursor_pos := Pos{
		x: 0
	}
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'f'

	mut amount := calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 3
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'f'

	amount = calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 13
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == '('
}

fn test_calc_w_move_amount_code_line() {
	// manually set the documents contents
	fake_line := 'fn (mut view View) w() int {'
	mut fake_cursor_pos := Pos{
		x: 0
	}

	mut amount := calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 3
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == '('

	amount = calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 1
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'm'

	amount = calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 4
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'v'

	amount = calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 5
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'V'

	amount = calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 4
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == ')'

	amount = calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 2
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'w'

	amount = calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 1
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == '('

	amount = calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 1
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == ')'

	amount = calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 2
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'i'

	amount = calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 4
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == '{'
}

fn test_calc_w_move_cursor_remains_on_same_line_when_encountering_floating_underscore() {
	// manually set the documents contents
	fake_lines := [
		"mut line_segments, _ := resolve_line_segments(resolve_text_syntax(), line, 0, false)",
		"this is the second line!"
	]

	fake_lines_str := arrays.join_to_string(fake_lines, '\n', fn (e string) string { return e })

	mut fake_cursor_pos := Pos{ x: 1 }

	mut amount := calc_w_move_amount(fake_cursor_pos, fake_lines_str, false)

	assert amount == 3
	fake_cursor_pos.x += amount
	assert fake_lines_str[fake_cursor_pos.x].ascii_str() == "l"

	amount = calc_w_move_amount(fake_cursor_pos, fake_lines_str, false)
	assert amount == 13
	fake_cursor_pos.x += amount
	assert fake_lines_str[fake_cursor_pos.x].ascii_str() == ","

	amount = calc_w_move_amount(fake_cursor_pos, fake_lines_str, false)
	assert amount == 2
	fake_cursor_pos.x += amount
	assert fake_lines_str[fake_cursor_pos.x].ascii_str() == "_"

	amount = calc_w_move_amount(fake_cursor_pos, fake_lines_str, false)
	assert amount == 2
	fake_cursor_pos.x += amount
	assert fake_lines_str[fake_cursor_pos.x].ascii_str() == ":"
}

fn test_calc_w_move_cursor_to_next_line_with_plain_comments() {
	// manually set the documents contents
	fake_lines := [
		'// Copyright 2023 The Lilly Editor contributors',
		'//',
		'// Licensed under the Apache License, Version 2.0 (the "License")',
	]

	fake_line := arrays.join_to_string(fake_lines, '\n', fn (e string) string {
		return e
	})

	mut fake_cursor_pos := Pos{
		x: 28
	}

	mut amount := calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 7
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'c'

	amount = calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 13
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == '/'

	amount = calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 3
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == '/'

	amount = calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 3
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'L'
}

fn test_count_repeated_sequence_multiple() {
	fake_line := '(((('
	assert '('.runes().len == 1
	assert count_repeated_sequence('('.runes()[0], fake_line.runes()) == 4
}

fn test_count_repeated_sequence_multiple_combined() {
	fake_line := '(((#####)))'
	assert count_repeated_sequence('('.runes()[0], fake_line.runes()) == 3
	assert count_repeated_sequence('#'.runes()[0], fake_line.runes()[3..]) == 5
	assert count_repeated_sequence(')'.runes()[0], fake_line.runes()[8..]) == 3
}

fn test_calc_w_move_amount_indented_code_line() {
	// manually set the document contents
	fake_line := '		for i := 0; i < 100; i++ {'
	mut fake_cursor_pos := Pos{
		x: 0
	}

	mut amount := calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 2
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'f'

	amount = calc_w_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 4
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'i'
}

fn test_calc_e_move_cursor_to_next_line_with_plain_comments() {
	// manually set the documents contents
	fake_lines := [
		'// Copyright 2023 The Lilly Editor contributors',
		'//',
		'// Licensed under the Apache License, Version 2.0 (the "License")',
	]

	fake_line := arrays.join_to_string(fake_lines, '\n', fn (e string) string {
		return e
	})

	mut fake_cursor_pos := Pos{
		x: 28
	}

	mut amount := calc_e_move_amount(fake_cursor_pos, fake_line, false)!
	assert amount == 5
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'r'

	amount = calc_e_move_amount(fake_cursor_pos, fake_line, false)!
	assert amount == 13
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == 's'

	amount = calc_e_move_amount(fake_cursor_pos, fake_line, false)!
	assert amount == 3
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == '/'

	amount = calc_e_move_amount(fake_cursor_pos, fake_line, false)!
	assert amount == 3
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == '/'

	amount = calc_e_move_amount(fake_cursor_pos, fake_line, false)!
	assert amount == 9
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'd'
}

fn test_calc_e_move_amount_to_end_of_repeated_sequence_of_special_char() {
	// manually set the documents contents
	fake_line := '(((#####)))'
	mut fake_cursor_pos := Pos{
		x: 0
	}
	assert fake_line[fake_cursor_pos.x].ascii_str() == '('

	mut amount := calc_e_move_amount(fake_cursor_pos, fake_line, false)!
	assert amount == 2
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == '('

	amount = calc_e_move_amount(fake_cursor_pos, fake_line, false)!
	assert amount == 5
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == '#'

	amount = calc_e_move_amount(fake_cursor_pos, fake_line, false)!
	assert amount == 3
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == ')'
}

fn test_calc_e_move_amount_to_end_of_repeated_sequence_of_special_char_with_whitespace_inbetween() {
	// manually set the documents contents
	fake_line := '(((    )))'
	mut fake_cursor_pos := Pos{
		x: 0
	}
	assert fake_line[fake_cursor_pos.x].ascii_str() == '('

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 2
	fake_cursor_pos.x += 2
	assert fake_line[fake_cursor_pos.x].ascii_str() == '('

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 7
	fake_cursor_pos.x += 7
	assert fake_line[fake_cursor_pos.x].ascii_str() == ')'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 0
	fake_cursor_pos.x += 0
	assert fake_line[fake_cursor_pos.x].ascii_str() == ')'
}

fn test_calc_e_move_amount_normal_sentence() {
	// manually set the document contents
	fake_line := 'This can read like a regularly structured sentence.'

	mut fake_cursor_pos := Pos{
		x: 0
	}
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'T'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 3
	fake_cursor_pos.x += 3
	assert fake_line[fake_cursor_pos.x].ascii_str() == 's'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 4
	fake_cursor_pos.x += 4
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'n'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 5
	fake_cursor_pos.x += 5
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'd'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 5
	fake_cursor_pos.x += 5
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'e'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 2
	fake_cursor_pos.x += 2
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'a'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 10
	fake_cursor_pos.x += 10
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'y'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 11
	fake_cursor_pos.x += 11
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'd'
}

fn test_calc_e_move_amount_code_line() {
	// manually set the document contents
	fake_line := 'status_green            = Color { 145, 237, 145 }'

	mut fake_cursor_pos := Pos{
		x: 0
	}

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 11
	fake_cursor_pos.x += 11
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'n'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 13
	fake_cursor_pos.x += 13
	assert fake_line[fake_cursor_pos.x].ascii_str() == '='

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 6
	fake_cursor_pos.x += 6
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'r'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 2
	fake_cursor_pos.x += 2
	assert fake_line[fake_cursor_pos.x].ascii_str() == '{'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 4
	fake_cursor_pos.x += 4
	assert fake_line[fake_cursor_pos.x].ascii_str() == '5'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 1
	fake_cursor_pos.x += 1
	assert fake_line[fake_cursor_pos.x].ascii_str() == ','

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 4
	fake_cursor_pos.x += 4
	assert fake_line[fake_cursor_pos.x].ascii_str() == '7'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 1
	fake_cursor_pos.x += 1
	assert fake_line[fake_cursor_pos.x].ascii_str() == ','

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 4
	fake_cursor_pos.x += 4
	assert fake_line[fake_cursor_pos.x].ascii_str() == '5'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 2
	fake_cursor_pos.x += 2
	assert fake_line[fake_cursor_pos.x].ascii_str() == '}'
}

fn test_calc_e_move_amount_code_line_two() {
	// manually set the document contents
	fake_line := 'fn name_of_function() {'
	mut fake_cursor_pos := Pos{
		x: 0
	}

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 1
	fake_cursor_pos.x += 1
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'n'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 17
	fake_cursor_pos.x += 17
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'n'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 1
	fake_cursor_pos.x += 1
	assert fake_line[fake_cursor_pos.x].ascii_str() == '('

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 1
	fake_cursor_pos.x += 1
	assert fake_line[fake_cursor_pos.x].ascii_str() == ')'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 2
	fake_cursor_pos.x += 2
	assert fake_line[fake_cursor_pos.x].ascii_str() == '{'
}

fn test_calc_e_move_amount_word_with_leading_whitespace() {
	// manually set the document contents
	fake_line := '    this'
	mut fake_cursor_pos := Pos{
		x: 0
	}

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 7
	fake_cursor_pos.x += 7
	assert fake_line[fake_cursor_pos.x].ascii_str() == 's'
}

fn test_calc_e_move_amount_two_words_with_leading_whitespace() {
	// manually set the document contents
	fake_line := '    this sentence'

	mut fake_cursor_pos := Pos{
		x: 0
	}

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 7
	fake_cursor_pos.x += 7
	assert fake_line[fake_cursor_pos.x].ascii_str() == 's'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 9
	fake_cursor_pos.x += 9
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'e'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 0
	fake_cursor_pos.x += 0
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'e'
}

fn test_calc_e_move_amount_multiple_words_with_leading_whitespace() {
	fake_line := '    this sentence is a test for this test'

	mut fake_cursor_pos := Pos{
		x: 0
	}

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 7
	fake_cursor_pos.x += 7
	assert fake_line[fake_cursor_pos.x].ascii_str() == 's'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 9
	fake_cursor_pos.x += 9
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'e'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 3
	fake_cursor_pos.x += 3
	assert fake_line[fake_cursor_pos.x].ascii_str() == 's'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 2
	fake_cursor_pos.x += 2
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'a'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 5
	fake_cursor_pos.x += 5
	assert fake_line[fake_cursor_pos.x].ascii_str() == 't'

	assert calc_e_move_amount(fake_cursor_pos, fake_line, false)! == 4
	fake_cursor_pos.x += 4
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'r'
}

fn test_calc_b_move_amount_to_end_of_repeated_sequence_of_special_char() {
	// manually set the documents contents
	fake_line := '(((#####)))'
	mut fake_cursor_pos := Pos{
		x: 10
	}
	assert fake_line[fake_cursor_pos.x].ascii_str() == ')'

	mut amount := calc_b_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 2
	fake_cursor_pos.x -= amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == ')'
	assert fake_cursor_pos.x == 8

	amount = calc_b_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 5
	fake_cursor_pos.x -= amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == '#'
	assert fake_cursor_pos.x == 3

	amount = calc_b_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 3
	fake_cursor_pos.x -= amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == '('
	assert fake_cursor_pos.x == 0
}

fn test_calc_b_move_amount_from_mid_first_word_to_line_start() {
	fake_line := '        status_green'

	mut fake_cursor_pos := Pos{
		x: 10
	}
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'a'

	mut amount := calc_b_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 2
	fake_cursor_pos.x -= amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == 's'

	amount = calc_b_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 8
	fake_cursor_pos.x -= amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == ' '
	assert fake_cursor_pos.x == 0
}

fn test_calc_b_move_amount_from_special_to_line_start() {
	fake_line := 'status_green            = Color  { 145, 237, 145 }'

	mut fake_cursor_pos := Pos{
		x: 24
	}
	assert fake_line[fake_cursor_pos.x].ascii_str() == '='

	mut amount := calc_b_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 24
	fake_cursor_pos.x -= amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == 's'
}

fn test_calc_b_move_amount_general() {
	fake_line := 'status_green            = Color  { 145, 237, 145 }'

	mut fake_cursor_pos := Pos{
		x: 43
	}
	assert fake_line[fake_cursor_pos.x].ascii_str() == ','

	mut amount := calc_b_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 3
	fake_cursor_pos.x -= amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == '2'

	amount = calc_b_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 2
	fake_cursor_pos.x -= amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == ','

	amount = calc_b_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 3
	fake_cursor_pos.x -= amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == '1'

	amount = calc_b_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 2
	fake_cursor_pos.x -= amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == '{'

	amount = calc_b_move_amount(fake_cursor_pos, fake_line, false)
	assert amount == 7
	fake_cursor_pos.x -= amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == 'C'
}

fn test_a_enters_insert_mode_after_cursor_position() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.buffer.lines = ['single line of text!']

	fake_view.cursor.pos.x = 0

	fake_view.a()

	assert fake_view.cursor.pos.x == 1
	assert fake_view.leader_state.mode == .insert
}

fn test_shift_a_enters_insert_mode_at_the_end_of_current_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.buffer.lines = ['some line of text', 'single line of text!', 'a third line!']

	fake_view.cursor.pos.y = 1
	// use random starting location, not at the start
	fake_view.cursor.pos.x = 3

	fake_view.shift_a()

	assert fake_view.cursor.pos.x == 20
	assert fake_view.cursor.pos.y == 1
	assert fake_view.leader_state.mode == .insert
}

fn test_r_replaces_character_in_middle_of_line() {
	mut clip := clipboardv2.new()
	mut lilly := Lilly{
		clipboard:         mut clip
	}
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.buffer.lines = ['some random line', 'another line of text', 'one last line']
	fake_view.cursor.pos.y = 2
	fake_view.cursor.pos.x = 4
	fake_view.r()

	assert fake_view.leader_state.mode == .replace

	event := draw.Event{
		code:  tui.KeyCode.p
		ascii: 112
		utf8:  'p'
	}
	fake_view.on_key_down(event, mut lilly)

	assert fake_view.leader_state.mode == .normal
	assert fake_view.buffer.lines[fake_view.cursor.pos.y] == 'one past line'
	assert fake_view.cursor.pos.x == 4
	assert fake_view.cursor.pos.y == 2
}

fn test_r_replaces_character_with_special_character() {
	mut clip := clipboardv2.new()
	mut lilly := Lilly{
		clipboard:         mut clip
	}
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.buffer.lines = ['some random line', 'another line of text', 'one last line']
	fake_view.cursor.pos.y = 2
	fake_view.cursor.pos.x = 8
	fake_view.r()

	assert fake_view.leader_state.mode == .replace

	event := draw.Event{
		code:  tui.KeyCode.exclamation
		ascii: 33
		utf8:  '!'
	}
	fake_view.on_key_down(event, mut lilly)

	assert fake_view.leader_state.mode == .normal
	assert fake_view.buffer.lines[fake_view.cursor.pos.y] == 'one last!line'
	assert fake_view.cursor.pos.x == 8
	assert fake_view.cursor.pos.y == 2
}

fn test_r_replaces_character_with_space() {
	mut clip := clipboardv2.new()
	mut lilly := Lilly{
		clipboard:         mut clip
	}
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.buffer.lines = ['some random line', 'another line of text', 'one last line']
	fake_view.cursor.pos.y = 2
	fake_view.cursor.pos.x = 4
	fake_view.r()

	assert fake_view.leader_state.mode == .replace

	event := draw.Event{
		code:  tui.KeyCode.space
		ascii: 32
		utf8:  ' '
	}
	fake_view.on_key_down(event, mut lilly)

	assert fake_view.leader_state.mode == .normal
	assert fake_view.buffer.lines[fake_view.cursor.pos.y] == 'one  ast line'
	assert fake_view.cursor.pos.x == 4
	assert fake_view.cursor.pos.y == 2
}

fn test_r_doesnt_change_anything_when_escape_is_used() {
	mut clip := clipboardv2.new()
	mut lilly := Lilly{
		clipboard:         mut clip
	}
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.buffer.lines = ['some random line', 'another line of text', 'one last line']
	fake_view.cursor.pos.y = 2
	fake_view.cursor.pos.x = 4
	fake_view.r()

	assert fake_view.leader_state.mode == .replace

	event := draw.Event{
		code:  tui.KeyCode.escape
		ascii: 27
	}
	fake_view.on_key_down(event, mut lilly)

	assert fake_view.leader_state.mode == .normal
	assert fake_view.cursor.pos.x == 4
	assert fake_view.cursor.pos.y == 2
	assert fake_view.buffer.lines[fake_view.cursor.pos.y] == 'one last line'
}

fn test_r_doesnt_change_anything_when_enter_is_used() {
	mut clip := clipboardv2.new()
	mut lilly := Lilly{
		clipboard:         mut clip
	}
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.buffer.lines = ['some random line', 'another line of text', 'one last line']
	fake_view.cursor.pos.y = 1
	fake_view.cursor.pos.x = 7
	fake_view.r()

	assert fake_view.leader_state.mode == .replace

	event := draw.Event{
		code:  tui.KeyCode.enter
		ascii: 10
	}
	fake_view.on_key_down(event, mut lilly)

	assert fake_view.leader_state.mode == .normal
	assert fake_view.cursor.pos.x == 7
	assert fake_view.cursor.pos.y == 1
	assert fake_view.buffer.lines[fake_view.cursor.pos.y] == 'another line of text'
}

fn test_shift_o_adds_line_above_cursor() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.buffer.lines = ['some line of text', 'another line of text']
	fake_view.cursor.pos.y = 1
	fake_view.cursor.pos.x = 7

	fake_view.shift_o()

	assert fake_view.buffer.lines.len == 3
	assert fake_view.buffer.lines[fake_view.cursor.pos.y] == ''
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 1
	assert fake_view.leader_state.mode == .insert
}

fn test_shift_o_adds_line_above_cursor_at_start_of_file() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.buffer.lines = ['some line of text', 'another line of text']
	fake_view.cursor.pos.y = 0
	fake_view.cursor.pos.x = 7

	fake_view.shift_o()

	assert fake_view.buffer.lines.len == 3
	assert fake_view.buffer.lines[fake_view.cursor.pos.y] == ''
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 0
	assert fake_view.leader_state.mode == .insert
}

fn test_x_removes_character_in_middle_of_line() {
	mut clip := clipboardv2.new()

	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.buffer.lines = ['this is a lines of text']
	fake_view.cursor.pos.y = 0
	fake_view.cursor.pos.x = 14

	fake_view.x()

	assert fake_view.buffer.lines == ['this is a line of text']
	assert fake_view.leader_state.mode == .normal
	assert fake_view.cursor.pos.x == 14
}

fn test_x_removes_character_and_shifts_cursor_back_at_end_of_line() {
	mut clip := clipboardv2.new()

	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.buffer.lines = ['this is a lines of text']
	fake_view.cursor.pos.y = 0
	fake_view.cursor.pos.x = 22

	// to show it reduces the length in later assertion
	assert fake_view.buffer.lines[fake_view.cursor.pos.y].len == 23

	fake_view.x()

	assert fake_view.buffer.lines == ['this is a lines of tex']
	assert fake_view.leader_state.mode == .normal
	assert fake_view.cursor.pos.x == 21
	assert fake_view.buffer.lines[fake_view.cursor.pos.y].len == 22

	fake_view.x()

	assert fake_view.buffer.lines == ['this is a lines of te']
	assert fake_view.leader_state.mode == .normal
	assert fake_view.cursor.pos.x == 20
	assert fake_view.buffer.lines[fake_view.cursor.pos.y].len == 21
}

fn test_find_position_within_word_lines() {
	assert find_position_within_word(0, 'Single'.runes()) == .start
	assert find_position_within_word(0, 'S word'.runes()) == .single_letter
	assert find_position_within_word(0, 'Multiple words'.runes()) == .start
	assert find_position_within_word(2, 'One or two words'.runes()) == .end
	assert find_position_within_word(11, 'Words with a single letter'.runes()) == .single_letter
}

fn test_auto_closing_square_brace() {
	mut clip := clipboardv2.new()
	mut lilly := Lilly{
		clipboard:         mut clip
	}
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.buffer.lines = ['']

	fake_view.cursor.pos.y = 0
	fake_view.cursor.pos.x = 0

	fake_view.i()

	mut event := draw.Event{
		code:  tui.KeyCode.left_square_bracket
		ascii: 91
	}
	fake_view.on_key_down(event, mut lilly)
	assert fake_view.buffer.lines == ['[]']

	assert fake_view.cursor.pos.x == 1 // ensure cursor is technically between the braces
}

fn test_auto_closing_curley_brace() {
	mut clip := clipboardv2.new()
	mut lilly := Lilly{
		clipboard:         mut clip
	}
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.buffer.lines = ['']

	fake_view.cursor.pos.y = 0
	fake_view.cursor.pos.x = 0

	fake_view.i()

	mut event := draw.Event{
		code:  tui.KeyCode.left_curly_bracket
		ascii: 91
	}
	fake_view.on_key_down(event, mut lilly)
	assert fake_view.buffer.lines == ['{}']

	assert fake_view.cursor.pos.x == 1 // ensure cursor is technically between the braces
}

fn test_auto_closing_curley_brace_inputting_secondary_close_should_only_move_cursor_pos() {
	mut clip := clipboardv2.new()
	mut lilly := Lilly{
		clipboard:         mut clip
	}
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.buffer.lines = ['']

	fake_view.cursor.pos.y = 0
	fake_view.cursor.pos.x = 0

	fake_view.i()

	mut event := draw.Event{
		code:  tui.KeyCode.left_curly_bracket
		ascii: 123
	}
	fake_view.on_key_down(event, mut lilly)
	assert fake_view.buffer.lines == ['{}']

	assert fake_view.cursor.pos.x == 1 // ensure cursor is technically between the braces

	event = draw.Event{
		code:  tui.KeyCode.right_curly_bracket
		ascii: 125
	}
	fake_view.on_key_down(event, mut lilly)
	assert fake_view.buffer.lines == ['{}'] // actual number of braces shouldn't have changed

	assert fake_view.cursor.pos.x == 2 // ensure cursor is on the far right side of both braces
}

fn test_auto_closing_square_brace_inputting_secondary_close_should_only_move_cursor_pos() {
	mut clip := clipboardv2.new()
	mut lilly := Lilly{
		clipboard:         mut clip
	}
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.buffer.lines = ['']

	fake_view.cursor.pos.y = 0
	fake_view.cursor.pos.x = 0

	fake_view.i()

	mut event := draw.Event{
		code:  tui.KeyCode.left_square_bracket
		ascii: 91
	}
	fake_view.on_key_down(event, mut lilly)
	assert fake_view.buffer.lines == ['[]']

	assert fake_view.cursor.pos.x == 1 // ensure cursor is technically between the braces

	event = draw.Event{
		code:  tui.KeyCode.right_square_bracket
		ascii: 93
	}
	fake_view.on_key_down(event, mut lilly)
	assert fake_view.buffer.lines == ['[]'] // actual number of braces shouldn't have changed

	assert fake_view.cursor.pos.x == 2 // ensure cursor is on the far right side of both braces
}

fn test_search_line_correct_overwrite() {
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: clipboardv2.new()
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.cmd_buf.err_msg = "previously run unrecognised command error message"

	fake_view.search()

	assert fake_view.leader_state.mode == .search
	assert fake_view.cmd_buf.err_msg == ''
	assert fake_view.cmd_buf.line == '//'
	assert fake_view.cmd_buf.cursor_x == 1
	assert fake_view.search.to_find == '/'
	assert fake_view.search.cursor_x == 1
}

fn test_view_draw_document() {
    mut fake_view := View{
		log: log.Log{}
        leader_state: ViewLeaderState{ mode: .normal }
        height: 15 // Set a small height for testing
		buffer: buffer.Buffer.new("", false)
    }

    fake_view.buffer.lines = [
        'Line 1', 'Line 2', 'Line 3', 'Line 4', 'Line 5',
        'Line 6', 'Line 7', 'Line 8', 'Line 9', 'Line 10',
        'Line 11', 'Line 12', 'Line 13', 'Line 14', 'Line 15'
    ]

	assert fake_view.from == 0

	mut drawn_text := []string{}
	mut ref := &drawn_text
	mut mock_drawer := TestDrawer{
		draw_text_callback: fn [mut ref] (x int, y int, text string) { ref << text }
		draw_rect_callback: unsafe { nil }
		window_height: fake_view.height
	}
	fake_view.draw(mut mock_drawer)

	assert fake_view.to == 13
	drawn_text_with_status_line_removed := drawn_text[..drawn_text.len - 13]
	assert drawn_text_with_status_line_removed == [
		"1", "Line 1", "2", "Line 2", "3", "Line 3", "4", "Line 4",
		"5", "Line 5", "6", "Line 6", "7", "Line 7", "8", "Line 8",
		"9", "Line 9", "10", "Line 10", "11", "Line 11", "12", "Line 12",
		"13", "Line 13"
	]
}

struct DrawnRect {
	x int
	y int
	width int
	height int
}

fn test_view_draw_document_with_method_using_buffer_view() {
	mut buf := buffer.Buffer.new("", false)
    buf.lines = [
        'Line 1', 'Line 2', 'Line 3', 'Line 4', 'Line 5',
        'Line 6', 'Line 7', 'Line 8', 'Line 9', 'Line 10',
        'Line 11', 'Line 12', 'Line 13', 'Line 14', 'Line 15'
    ]

    mut fake_view := View{
		log: log.Log{}
        leader_state: ViewLeaderState{ mode: .normal }
        height: 15 // Set a small height for testing
		buffer: buf
    }
	fake_view.buf_view = ui.BufferView.new(&fake_view.buffer)

	assert fake_view.from == 0

	mut drawn_text := []string{}
	mut drawn_text_ref := &drawn_text

	mut drawn_rects := []DrawnRect{}
	mut drawn_rects_ref := &drawn_rects

	mut mock_drawer := TestDrawer{
		draw_text_callback: fn [mut drawn_text_ref] (x int, y int, text string) { drawn_text_ref << text }
		draw_rect_callback: fn [mut drawn_rects_ref] (x int, y int, width int, height int) { drawn_rects_ref << DrawnRect{ x, y, width, height } }
		window_height: fake_view.height
	}
	fake_view.draw_x(mut mock_drawer)

	assert fake_view.to == 13
	drawn_text_with_status_line_removed := drawn_text[..drawn_text.len - 13]
	assert drawn_text_with_status_line_removed == [
		"1", "Line", " ", "1", "2", "Line", " ", "2", "3", "Line", " ", "3", "4", "Line", " ", "4",
		"5", "Line", " ", "5", "6", "Line", " ", "6", "7", "Line", " ", "7", "8", "Line", " ", "8",
		"9", "Line", " ", "9", "10", "Line", " ", "10", "11", "Line", " ", "11", "12", "Line", " ", "12",
		"13", "Line", " ", "13"
	]
	assert drawn_rects == [
		DrawnRect{ x: 4, y: 1, width: 497, height: 1 }   // this is the cursor highlight rect line
		DrawnRect{ x: 16, y: 13, width: 477, height: 1 } // this is the gap spread in the status line
	]
}

// TODO(tauraamui) [18/03/2025]: re-enable this test
/*
fn test_scroll_view_down() {
    mut fake_view := View{
		log: log.Log{}
        leader_state: ViewLeaderState{ mode: .normal }
        height: 10 // Set a small height for testing
		buffer: buffer.Buffer.new("", false)
    }

    // Create a document with more lines than the view height
    fake_view.buffer.lines = [
        'Line 1', 'Line 2', 'Line 3', 'Line 4', 'Line 5',
        'Line 6', 'Line 7', 'Line 8', 'Line 9', 'Line 10',
        'Line 11', 'Line 12', 'Line 13', 'Line 14', 'Line 15'
    ]

	assert fake_view.from == 0

	mut drawn_text := []string{}
	mut ref := &drawn_text
	mut mock_drawer := TestDrawer{
		draw_text_callback: fn [mut ref] (x int, y int, text string) { ref << text }
		window_height: fake_view.height
	}
	fake_view.draw(mut mock_drawer)

	assert fake_view.to == 8

	assert drawn_text.len > 0
	mut cleaned_list := drawn_text[0..drawn_text.len - 13].clone()
	assert cleaned_list == [
		"1", "Line 1",
		"2", "Line 2",
		"3", "Line 3",
		"4", "Line 4",
		"5", "Line 5",
		"6", "Line 6",
		"7", "Line 7",
		"8", "Line 8",
		"9", "Line 9"
	]

	for _ in 0..20 {
		fake_view.scroll_up()
	}

	drawn_text.clear()
	fake_view.draw(mut mock_drawer)
	cleaned_list = drawn_text[0..drawn_text.len - 13].clone()
	assert cleaned_list == [
		"14", "Line 14",
		"15", "Line 15"
	]

	assert fake_view.from         == 13 // this is unexpected/wrong, I don't know how the viewport is even working atm
	assert fake_view.cursor.pos.y == 14
}
*/

fn test_center_text_around_cursor() {
    mut fake_view := View{
		log: log.Log{}
        leader_state: ViewLeaderState{ mode: .normal }
        height: 10 // Set a small height for testing
		buffer: buffer.Buffer.new("", false)
    }

    // Create a document with more lines than the view height
    fake_view.buffer.lines = [
        'Line 1', 'Line 2', 'Line 3', 'Line 4', 'Line 5',
        'Line 6', 'Line 7', 'Line 8', 'Line 9', 'Line 10',
        'Line 11', 'Line 12', 'Line 13', 'Line 14', 'Line 15'
    ]

    // Set initial view bounds
    fake_view.from = 0
    fake_view.to = 10

    // Set cursor to Line 8
    fake_view.cursor.pos.y = 7
    mut original_cursor_pos := fake_view.cursor.pos.y

    // Call the center_text_around_cursor function
    fake_view.center_text_around_cursor()

    // Check if the cursor position remains unchanged
    assert fake_view.cursor.pos.y == original_cursor_pos

    // Check if the view is centered correctly
	// The '+2' is to account for the extra lines in the total
	// height of the view, used so we don't run off the bottom
	// of the view
    assert fake_view.from <= original_cursor_pos
    assert fake_view.to > original_cursor_pos
    assert (fake_view.to - fake_view.from)+2 == fake_view.height

    // Move cursor to the end and test again
    fake_view.cursor.pos.y = 14
    original_cursor_pos = fake_view.cursor.pos.y
    fake_view.center_text_around_cursor()

    // Check if the cursor position remains unchanged
    assert fake_view.cursor.pos.y == original_cursor_pos

    // Check if the view is adjusted for the end of the document
	// The '+5' is to account for the extra lines in the total
    assert fake_view.from <= original_cursor_pos
    assert fake_view.to+5 == fake_view.buffer.lines.len
}

fn test_zero_key_handling() {
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		buffer: buffer.Buffer.new("", false)
	}

	fake_view.buffer.lines = ['    This is a test line', 'Another line']

	// Set cursor to middle of first line
	fake_view.cursor.pos.x = 10
	fake_view.cursor.pos.y = 0

	// Simulate '0' key press
	fake_view.zero()

	// Verify cursor moved to start of line
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 0

	// Test that other number keys still append to chord repeat amount
	fake_view.chord.append_to_repeat_amount('5')
	assert fake_view.chord.pending_repeat_amount() == '5'

	// Ensure '0' doesn't append to repeat amount when it's the first number
	fake_view.chord.reset()
	fake_view.zero()
	assert fake_view.chord.pending_repeat_amount() == ''
}

fn test_repeat_command_with_chord_repeat_amount() {
    mut fake_view := View{
		log: log.Log{}
        leader_state: ViewLeaderState{ mode: .normal }
        height: 40
		buffer: buffer.Buffer.new("", false)
    }

    // Set initial view bounds
    fake_view.from = 0
    fake_view.to = 0

	// Test that the chord starting with a '0' doesn't move the cursor
	fake_view.chord.append_to_repeat_amount('0')
	assert fake_view.chord.pending_repeat_amount() == '0'

	// Verify cursor moved to start of line
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 0

	// Ensure '0' doesn't append to repeat amount when it's the first number
	fake_view.chord.reset()
	fake_view.zero()
	assert fake_view.chord.pending_repeat_amount() == ''

	// Test that the chord starting with a number then followed
	// by a '0' moves the cursor the correct number of times
	// This ensures that view.zero() isn't soaking up these zeros here!
	fake_view.chord.reset()
	fake_view.chord.append_to_repeat_amount('1')
	fake_view.chord.append_to_repeat_amount('0')
	assert fake_view.chord.pending_repeat_amount() == "10"

	op := fake_view.chord.j()
	assert op.kind == .move
	assert op.direction == .down
	assert op.repeat == 10

	// Test that the chord starting with a '0', then followed a number,
	// then another '0' still moves the cursor the correct number of times
	// This just tests if a view.zero() somehow doesn't trigger when
	// pressing the zero key one or more times!!
	fake_view.chord.reset()
	fake_view.chord.append_to_repeat_amount('0')
	fake_view.chord.append_to_repeat_amount('2')
	fake_view.chord.append_to_repeat_amount('0')
	assert fake_view.chord.pending_repeat_amount() == "020"

	op2 := fake_view.chord.j()
	assert op2.kind == .move
	assert op2.direction == .down
	assert op2.repeat == 20
}

fn test_f_finds_in_current_line_command() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = ['The quick brown fox jumps over the lazy dog']
	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 0

	event := draw.Event{
		code:  tui.KeyCode.q
		ascii: 113
		utf8:  'q'
	}
	fake_view.f(event)
	fake_view.f(event)

	assert fake_view.cursor.pos.x == 5
}

fn test_gg_goes_to_top_of_file_command() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = ['Line 1', 'Line 2', 'Line 3']
	fake_view.cursor.pos.y = 2

	fake_view.g()
	fake_view.g()

	assert fake_view.cursor.pos.y == 0
}

fn test_left_square_brace_goes_to_top_of_file() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = []string{}
	for i in 0..100 {
		fake_view.buffer.lines << "Line ${i}"
	}
	fake_view.from = 50
	fake_view.to = 100
	fake_view.cursor.pos.y = 80

	fake_view.left_square_bracket()
	fake_view.left_square_bracket()

	assert fake_view.cursor.pos.y == 0
	assert fake_view.from == 0
	assert fake_view.to == 50
}

fn test_shift_g_goes_to_bottom_of_file_command() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = ['Line 1', 'Line 2', 'Line 3']
	fake_view.cursor.pos.y = 2

	fake_view.shift_g()

	assert fake_view.cursor.pos.y == 2
}

fn test_right_square_brace_goes_to_top_of_file() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = []string{}
	for i in 0..100 {
		fake_view.buffer.lines << "Line ${i}"
	}
	fake_view.from = 0
	fake_view.to = 50
	fake_view.cursor.pos.y = 30

	fake_view.right_square_bracket()
	fake_view.right_square_bracket()

	assert fake_view.cursor.pos.y == 99
	assert fake_view.from == 50
	// NOTE(tauraamui) [12/01/25]: at the moment from and to scrolling only really moves "from"
	//                             in some situations to does not move but this all still somehow
	//                             works. This needs to be investigated and re-worked.
	assert fake_view.to == 50
}

fn test_shift_r_replaces_character_in_line_command() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = ['The quick brown fox']
	fake_view.cursor.pos.x = 2
	fake_view.cursor.pos.y = 0

	fake_view.leader_state.mode = .replacing
	fake_view.replace_char(113, 'q')  // ASCII 113 is 'q'
	assert fake_view.buffer.lines[0] == 'Thq quick brown fox'

	fake_view.replace_char(112, 'p')  // ASCII 113 is 'q'
	assert fake_view.buffer.lines[0] == 'Thp quick brown fox'

	fake_view.escape()
	assert fake_view.leader_state.mode == .normal
}

fn test_shift_l_goes_to_lowest_part_of_view_command() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		height: 10
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = ['Line 1', 'Line 2', 'Line 3', 'Line 4', 'Line 5', 'Line 6', 'Line 7', 'Line 8', 'Line 9', 'Line 10']
	fake_view.from = 0
	fake_view.to = 10

	fake_view.shift_l()

	assert fake_view.cursor.pos.y == 9
}

fn test_shift_m_goes_to_middle_part_of_view_command() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		height: 10
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = ['Line 1', 'Line 2', 'Line 3', 'Line 4', 'Line 5', 'Line 6', 'Line 7', 'Line 8', 'Line 9', 'Line 10']
	fake_view.from = 0
	fake_view.to = 10

	fake_view.shift_m()

	assert fake_view.cursor.pos.y == 5
}

fn test_shift_h_goes_to_highest_part_of_view_command() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		height: 10
		buffer: buffer.Buffer.new("", false)
	}
	fake_view.buffer.lines = ['Line 1', 'Line 2', 'Line 3', 'Line 4', 'Line 5', 'Line 6', 'Line 7', 'Line 8', 'Line 9', 'Line 10']
	fake_view.from = 0
	fake_view.to = 10

	fake_view.shift_h()

	assert fake_view.cursor.pos.y == 0
}
