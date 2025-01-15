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

import lib.draw

fn (mut view View) on_key_down(e draw.Event, mut root Root) {
	match view.leader_state.mode {
		.leader {
			match e.code {
				.escape {
					view.escape()
				}
				.x {
					if !view.leader_state.normal { view.leader_state.special = true }
					view.leader_state.x_count += 1
				}
				.f {
					if !view.leader_state.special { view.leader_state.normal = true }
					view.leader_state.f_count += 1
					if view.leader_state.f_count == 2 {
						root.open_file_finder(view.leader_state.special)
						view.escape()
					}
				}
				.b {
					if !view.leader_state.special { view.leader_state.normal = true }
					view.leader_state.b_count += 1
					if view.leader_state.f_count == 1 && view.leader_state.b_count == 1 {
						root.open_inactive_buffer_finder(view.leader_state.special)
						view.escape()
					}
				}
				else {}
			}
		}
		.normal {
			match e.utf8 {
				view.leader_key { view.leader_state.mode = .leader }
				else {}
			}
			match e.code {
				.escape {
					view.escape()
				}
				.h {
					if e.modifiers == .shift {
						view.shift_h()
					} else {
						view.exec(view.chord.h())
					}
				}
				.l {
					if e.modifiers == .shift {
						view.shift_l()
					} else {
						view.exec(view.chord.l())
					}
				}
				.m {
					if e.modifiers == .shift {
						view.shift_m()
					} else {
					}
				}
				.j {
					view.exec(view.chord.j())
				}
				.k {
					view.exec(view.chord.k())
				}
				.i {
					view.exec(view.chord.i())
				}
				.v {
					match e.modifiers {
						.shift { view.shift_v() }
						else { view.v() }
					}
				}
				.e {
					view.exec(view.chord.e())
				}
				.w {
					view.exec(view.chord.w())
				}
				.b {
					view.exec(view.chord.b())
				}
				.o {
					if e.modifiers == .shift {
						view.shift_o()
					} else {
						view.o()
					}
				}
				.a {
					if e.modifiers == .shift {
						view.shift_a()
					} else {
						view.a()
					}
				}
				.p {
					view.exec(view.chord.p())
				}
				.g {
					if e.modifiers == .shift {
						view.shift_g()
					} else {
						view.g()
					}
				}
				.f {
					view.f(e)
				}
				.r {
					if e.modifiers == .shift {
						view.leader_state.mode = .replacing
					} else {
						view.r()
					}
				} // TODO(tauraamui): request Valentine implements chord usage for this
				.x {
					view.x()
				} // TODO(tauraamui): request Valentine implements chord usage for this
				.left {
					view.exec(view.chord.h())
				}
				.right {
					view.exec(view.chord.l())
				}
				.down {
					view.exec(view.chord.j())
				}
				.up {
					view.exec(view.chord.k())
				}
				.c {
					view.exec(view.chord.c())
				}
				.z     { view.z() }
				.d {
					if e.modifiers == .ctrl {
						view.ctrl_d()
					} else {
						view.d()
					}
				} // TODO(tauraamui): this will need some special attention to implement
				.u {
					if e.modifiers == .ctrl {
						view.ctrl_u()
					} else {
						view.u()
					}
				}
				.caret {
					view.hat()
				}
				.dollar {
					view.dollar()
				}
				.left_curly_bracket {
					view.jump_cursor_up_to_next_blank_line()
				}
				.right_curly_bracket {
					view.jump_cursor_down_to_next_blank_line()
				}
				.colon {
					view.cmd()
				}
				.left_square_bracket {
					view.left_square_bracket()
				}
				.right_square_bracket {
					view.right_square_bracket()
				}
				.slash {
					view.search()
				}
				48...48 {
					if view.chord.pending_repeat_amount() != '' {
						view.chord.append_to_repeat_amount(e.ascii.ascii_str())
					} else {
						view.zero()
					}
				}
				49...57 { // 0-9a
					view.chord.append_to_repeat_amount(e.ascii.ascii_str())
				}
				else {}
			}
		}
		.visual {
			match e.code {
				.escape {
					view.escape()
				}
				.e {
					view.exec(view.chord.e())
				}
				.w {
					view.exec(view.chord.w())
				}
				.b {
					view.exec(view.chord.b())
				}
				.h {
					view.h()
				}
				.l {
					view.l()
				}
				.j {
					view.j()
				}
				.k {
					view.k()
				}
				.up {
					view.k()
				}
				.right {
					view.l()
				}
				.down {
					view.j()
				}
				.left {
					view.h()
				}
				.d {
					if e.modifiers == .ctrl {
						view.ctrl_d()
					} else {
						// view.visual_d(true)
						view.d()
					}
				}
				.caret {
					view.hat()
				}
				.dollar {
					view.dollar()
				}
				.left_curly_bracket {
					view.jump_cursor_up_to_next_blank_line()
				}
				.right_curly_bracket {
					view.jump_cursor_down_to_next_blank_line()
				}
				.left_square_bracket {
					view.left_square_bracket()
				}
				.right_square_bracket {
					view.right_square_bracket()
				}
				.y {
					// view.visual_y()
					view.y()
				}
				else {}
			}
		}
		.visual_line {
			match e.code {
				.escape {
					view.escape()
				}
				.h {
					view.h()
				}
				.l {
					view.l()
				}
				.j {
					view.j()
				}
				.k {
					view.k()
				}
				.up {
					view.k()
				}
				.right {
					view.l()
				}
				.down {
					view.j()
				}
				.left {
					view.h()
				}
				.less_than {
					view.visual_unindent()
				}
				.greater_than {
					view.visual_indent()
				}
				.d {
					if e.modifiers == .ctrl {
						view.ctrl_d()
					} else {
						view.d()
						// view.visual_line_d(true)
					}
				}
				.p {
					view.exec(view.chord.p())
				}
				// NOTE(tauraamui): undo bind is now disabled until the feature is re-done
				// .u { if e.modifiers == .ctrl { view.ctrl_u() } }
				.caret {
					view.hat()
				}
				.dollar {
					view.dollar()
				}
				.left_curly_bracket {
					view.jump_cursor_up_to_next_blank_line()
				}
				.right_curly_bracket {
					view.jump_cursor_down_to_next_blank_line()
				}
				.y {
					view.y()
					// view.visual_line_y()
				}
				else {}
			}
		}
		.command {
			match e.code {
				.escape {
					view.escape()
				}
				.enter {
					view.cmd_buf.exec(mut view, mut root)
					view.leader_state.mode = .normal
				}
				.space {
					view.cmd_buf.put_char(' ')
				}
				48...57, 97...122 { // 0-9a-zA-Z
					view.cmd_buf.put_char(e.ascii.ascii_str())
				}
				.left {
					view.cmd_buf.left()
				}
				.right {
					view.cmd_buf.right()
				}
				.up {
					view.cmd_buf.up()
				}
				.down {
					return
				}
				.backspace {
					view.cmd_buf.backspace()
				}
				else {
					view.cmd_buf.put_char(e.ascii.ascii_str())
				}
			}
		}
		.search {
			match e.code {
				.escape {
					view.escape()
				}
				.space {
					view.search.put_char(' ')
				}
				48...57, 97...122 { // 0-9a-zA-Z
					view.search.put_char(e.ascii.ascii_str())
				}
				.left {
					view.search.left()
				}
				.right {
					view.search.right()
				}
				.up {}
				.down {}
				.backspace {
					view.search.backspace()
				}
				.enter {
					view.search.find(view.buffer.lines)
				}
				.tab {
					pos := view.search.next_find_pos() or { return }
					view.jump_cursor_to(pos.line)
				}
				else {
					view.search.put_char(e.ascii.ascii_str())
				}
			}
		}
		.insert {
			if e.modifiers == .ctrl {
				return
			}
			// ignore the ASCII group separators
			// FS, GS and RS
			match e.ascii {
				28...31 { return }
				else {}
			}
			match e.code {
				// ignored/currently "handled" but rejected keys
				.f1 {}
				.f2 {}
				.f3 {}
				.f4 {}
				.f5 {}
				.f6 {}
				.f7 {}
				.f8 {}
				.f9 {}
				.f10 {}
				.f11 {}
				.f12 {}
				.delete {}
				.insert {}
				.home {}
				.page_up {}
				.page_down {}
				.end {}
				.up {}
				.down {}
				//
				.escape {
					view.escape()
				}
				.enter {
					view.enter()
				}
				.backspace {
					view.backspace()
				}
				.left {
					view.left()
				}
				.right {
					view.right()
				}
				.tab {
					view.insert_tab()
				}
				.single_quote {
					view.insert_text("''")
					view.cursor.pos.x -= 1
					view.clamp_cursor_x_pos()
				}
				.double_quote {
					view.insert_text('""')
					view.cursor.pos.x -= 1
					view.clamp_cursor_x_pos()
				}
				.left_paren {
					view.insert_text('()')
					view.cursor.pos.x -= 1
					view.clamp_cursor_x_pos()
					view.buffer.auto_close_chars << '('
				}
				.left_curly_bracket {
					view.insert_text('{}')
					view.cursor.pos.x -= 1
					view.clamp_cursor_x_pos()
					view.buffer.auto_close_chars << '{'
				}
				.left_square_bracket {
					view.insert_text('[]')
					view.cursor.pos.x -= 1
					view.clamp_cursor_x_pos()
					view.buffer.auto_close_chars << '['
				}
				.right_paren {
					view.close_pair_or_insert(e.ascii.ascii_str())
				}
				.right_curly_bracket {
					view.close_pair_or_insert(e.ascii.ascii_str())
				}
				.right_square_bracket {
					view.close_pair_or_insert(e.ascii.ascii_str())
				}
				48...57, 97...122 { // 0-9A-Z
					view.insert_text(e.utf8)
				}
				else {
					// buf := [5]u8{}
					// s := unsafe { utf32_to_str_no_malloc(u32(e.code), &buf[0]) }
					view.insert_text(e.utf8)
				}
			}
		}
		.pending_delete {
			match e.code {
				.escape { view.escape() }
				.d { view.d() }
				else {}
			}
		}
		.pending_z {
			match e.code {
				.escape { view.escape() }
				.z { view.z() }
				else {}
			}
		}
		.pending_g {
			match e.code {
				.escape { view.escape() }
				.g { view.g() }
				else {}
			}
		}
		.pending_f {
			match e.code {
				.escape { view.escape() }
				else { view.f(e) }
			}
		}
		.replace, .replacing {
			match e.code {
				.escape {
					view.escape_replace()
				}
				.enter {
					view.escape_replace()
				}
				.backspace {}
				.up {}
				.down {}
				.left {}
				.right {}
				.tab {}
				else {
					view.replace_char(e.ascii, e.utf8)
					view.clamp_cursor_x_pos()
					if view.leader_state.mode == .replace {
						view.escape_replace()
					}
				}
			}
		}
	}
}
