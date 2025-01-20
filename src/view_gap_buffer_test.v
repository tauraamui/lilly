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

import log
import lib.clipboardv2
import lib.buffer
import lib.workspace

// NOTE(tauraamui) [07/01/25]: there is a lot of duplication in the setup of these tests
//                  also, the fact that we're invoking the edit related methods
//                  on view directly technically means that the .mode value is
//                  irrelevant

fn test_insert_text() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("1. first line\n2. second line")

	fake_view.insert_text("Random words!")

	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"Random words!1. first line",
		"2. second line"
	]
}

fn test_insert_tab() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("1. first line\n2. second line")

	fake_view.cursor.pos.x = 3
	fake_view.insert_tab()

	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"1.     first line",
		"2. second line"
	]

	assert fake_view.cursor.pos.x == 7
	assert fake_view.cursor.pos.y == 0
}

fn test_shift_o_inserts_empty_line_above_current() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("1. first line\n2. second line\n3. third line")

	fake_view.cursor.pos.y = 1

	fake_view.shift_o()

	assert fake_view.leader_state.mode == .insert
	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"1. first line"
		""
		"2. second line"
		"3. third line"
	]
	assert fake_view.cursor.pos.y == 1
}

fn test_shift_o_inserts_empty_line_above_current_first_line_of_document() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("1. first line\n2. second line\n3. third line")

	fake_view.cursor.pos.y = 0

	fake_view.shift_o()

	assert fake_view.leader_state.mode == .insert
	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		""
		"1. first line"
		"2. second line"
		"3. third line"
	]
	assert fake_view.cursor.pos.y == 0
}

fn test_o_inserts_empty_line_below_current() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("1. first line\n2. second line\n3. third line")

	fake_view.cursor.pos.y = 1

	fake_view.o()

	assert fake_view.leader_state.mode == .insert
	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"1. first line"
		"2. second line"
		""
		"3. third line"
	]
	assert fake_view.cursor.pos.y == 2
}

fn test_o_inserts_empty_line_below_current_last_line_of_document() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("1. first line\n2. second line\n3. third line")

	fake_view.cursor.pos.y = 2

	fake_view.o()

	assert fake_view.leader_state.mode == .insert
	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"1. first line"
		"2. second line"
		"3. third line"
		""
	]
	assert fake_view.cursor.pos.y == 3
}

fn test_x_removes_characters_on_single_line_document() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("This is a single line document that happens to be quite long.")

	fake_view.cursor.pos.x = 20
	fake_view.x()
	fake_view.x()
	fake_view.x()
	fake_view.x()

	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"This is a single lincument that happens to be quite long."
	]
	assert fake_view.cursor.pos.x == 20
	assert fake_view.cursor.pos.y == 0
}

fn test_x_removes_from_cursor_then_move_cursor_left_one() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("0000000011111111222222223333333344444444")

	fake_view.h()
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 0

	fake_view.x()

	fake_view.h()

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 0
}

fn test_x_removes_from_cursor_on_line_with_single_char_then_move_cursor_right_one() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("012")

	assert fake_view.buffer.raw_str() == "${'_'.repeat(buffer.gap_size)}012"

	fake_view.l()
	assert fake_view.cursor.pos.x == 1
	assert fake_view.cursor.pos.y == 0

	fake_view.x()
	assert fake_view.buffer.str() == "02"

	fake_view.l()

	assert fake_view.cursor.pos.x == 1
	assert fake_view.cursor.pos.y == 0
}


fn test_x_removes_from_cursor_then_move_cursor_right_one() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("0000000011111111222222223333333344444444")

	fake_view.cursor.pos.x = 38

	fake_view.l()
	assert fake_view.cursor.pos.x == 39
	assert fake_view.cursor.pos.y == 0

	fake_view.x()

	assert fake_view.buffer.str() == "000000001111111122222222333333334444444"

	fake_view.l()

	assert fake_view.cursor.pos.x == 39
	assert fake_view.cursor.pos.y == 0
}

fn test_x_removes_from_cursor_to_end_of_line_and_beyond() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("0000000011111111222222223333333344444444")

	fake_view.cursor.pos.x = 32

	fake_view.x()
	assert fake_view.buffer.str() == "000000001111111122222222333333334444444"

	fake_view.x()
	assert fake_view.buffer.str() == "00000000111111112222222233333333444444"

	fake_view.x()
	assert fake_view.buffer.str() == "0000000011111111222222223333333344444"

	fake_view.x()
	assert fake_view.buffer.str() == "000000001111111122222222333333334444"

	fake_view.x()
	assert fake_view.buffer.str() == "00000000111111112222222233333333444"

	fake_view.x()
	assert fake_view.buffer.str() == "0000000011111111222222223333333344"

	fake_view.x()
	assert fake_view.buffer.str() == "000000001111111122222222333333334"

	fake_view.x()
	assert fake_view.buffer.str() == "00000000111111112222222233333333"

	assert fake_view.cursor.pos.x == 32
	assert fake_view.cursor.pos.y == 0
}

fn test_x_does_not_remove_characters_on_multi_line_document_if_at_line_end() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("1. first line\n2. second line\n3. third line")

	fake_view.cursor.pos.x = fake_view.buffer.find_end_of_line(buffer.Pos{ y: fake_view.cursor.pos.y }) or { 0 }
	fake_view.x()

	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"1. first line"
		"2. second line"
		"3. third line"
	]
	assert fake_view.cursor.pos.x == 13
	assert fake_view.cursor.pos.y == 0
}

fn test_x_removes_characters_up_to_end_of_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("1. first line\n2. second line\n3. third line")

	for _ in 0..14 { // slightly beyond end of line
		fake_view.x()
	}

	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		""
		"2. second line"
		"3. third line"
	]
	assert fake_view.cursor.pos.y == 0
}

fn test_w_moves_to_start_of_next_word() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("This is the first line.\n2. second line")

	fake_view.w()
	assert fake_view.cursor.pos.x == 5
	assert fake_view.cursor.pos.y == 0

	fake_view.w()
	assert fake_view.cursor.pos.x == 8
	assert fake_view.cursor.pos.y == 0
}

fn test_w_moves_to_start_of_next_line_if_on_empty_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("This is the first line.\n\n2. second line")

	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 1

	fake_view.w()
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 2

	fake_view.w()
	assert fake_view.cursor.pos.x == 3
	assert fake_view.cursor.pos.y == 2
}

fn test_w_moves_from_blank_line_to_next() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("\n\n\n\n\n")

	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 0

	fake_view.w()
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 1

	fake_view.w()
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 2

	fake_view.w()
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 3

	fake_view.w()
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 4

	fake_view.w()
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 4
}

fn test_w_moves_from_end_line_to_blank_next_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("T\n\nX\n")

	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 0

	fake_view.w()
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 1

	fake_view.w()
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 2
}

fn test_w_moves_from_end_of_word_to_start_of_next() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("First      Word")

	fake_view.cursor.pos.x = 4
	fake_view.cursor.pos.y = 0

	fake_view.w()
	assert fake_view.cursor.pos.x == 11
	assert fake_view.cursor.pos.y == 0

	fake_view.w()
	assert fake_view.cursor.pos.x == 11
	assert fake_view.cursor.pos.y == 0
}

fn test_w_moves_to_start_of_next_word_across_a_newline() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("This is the first line.\n2. second line")

	fake_view.cursor.pos.x = 12

	fake_view.w()
	assert fake_view.cursor.pos.x == 18
	assert fake_view.cursor.pos.y == 0

	fake_view.w()
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 1

	fake_view.w()
	assert fake_view.cursor.pos.x == 3
	assert fake_view.cursor.pos.y == 1
}

fn test_w_moves_to_start_of_next_word_up_to_document_end() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("This is the first line.\n2. second line")

	fake_view.cursor.pos.x = 10
	fake_view.cursor.pos.y = 1

	fake_view.w()
	assert fake_view.cursor.pos.x == 10
	assert fake_view.cursor.pos.y == 1
}

fn test_w_moves_to_start_of_next_word_from_whitespace() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("                This is the first line.")

	fake_view.cursor.pos.x = 3
	fake_view.cursor.pos.y = 0

	fake_view.w()
	assert fake_view.cursor.pos.x == 16
	assert fake_view.cursor.pos.y == 0
}

fn test_e_moves_to_end_of_next_word() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("This is a line, the first line.\n2. second line")

	fake_view.e()
	assert fake_view.cursor.pos.x == 3
	assert fake_view.cursor.pos.y == 0

	fake_view.e()
	assert fake_view.cursor.pos.x == 6
	assert fake_view.cursor.pos.y == 0

	fake_view.e()
	assert fake_view.cursor.pos.x == 8
	assert fake_view.cursor.pos.y == 0

	fake_view.e()
	assert fake_view.cursor.pos.x == 14
	assert fake_view.cursor.pos.y == 0
}

fn test_e_moves_from_blank_line_to_next() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("\n\n\n\n\n")

	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 0

	fake_view.e()
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 1

	fake_view.e()
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 2

	fake_view.e()
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 3

	fake_view.e()
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 4

	fake_view.e()
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 4
}

fn test_b_moves_to_start_of_current_word() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("This is a line, the first line.\n2. second line")

	fake_view.cursor.pos.x = 6
	fake_view.cursor.pos.y = 0

	fake_view.b()
	assert fake_view.cursor.pos.x == 5
	assert fake_view.cursor.pos.y == 0

	fake_view.b()
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 0
}

fn test_b_moves_to_end_of_previous_line_if_on_empty_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("This is the first line.\n2. second line")

	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 1

	fake_view.b()
	assert fake_view.cursor.pos.y == 0
	assert fake_view.cursor.pos.x == 18
}

/*
fn test_b_moves_from_blank_line_to_next() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("\n\n\n\n\n")

	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 2

	fake_view.b()
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 1

	fake_view.b()
	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 0
}
*/

fn test_enter_inserts_newline_at_cursor_in_middle_of_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("This is a sentence, it is in fact the first sentence.")

	fake_view.cursor.pos.x = 20
	fake_view.cursor.pos.y = 0

	fake_view.enter()

	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"This is a sentence, ",
		"it is in fact the first sentence."
	]

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 1
}

fn test_enter_inserts_newline_at_cursor_in_line_multiple_times() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("This is a sentence, it is in fact the first sentence.")

	fake_view.cursor.pos.x = 20
	fake_view.cursor.pos.y = 0

	fake_view.enter()
	fake_view.enter()
	fake_view.enter()

	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"This is a sentence, ",
		"",
		"",
		"it is in fact the first sentence."
	]

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 3
}

fn test_enter_inserts_newline_at_cursor_at_start_of_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("This is a sentence, it is in fact the first sentence.")

	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 0

	fake_view.enter()

	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"",
		"This is a sentence, it is in fact the first sentence."
	]

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 1
}

fn test_enter_inserts_newline_at_cursor_at_end_of_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("This is a sentence, it is in fact the first sentence.")

	fake_view.cursor.pos.x = 53
	fake_view.cursor.pos.y = 0

	fake_view.enter()

	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"This is a sentence, it is in fact the first sentence.",
		""
	]

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 1
}

fn test_backspace_deletes_character_at_cursor_in_middle_of_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("This is a sentence, it is in fact the first sentence.")

	fake_view.cursor.pos.x = 20
	fake_view.cursor.pos.y = 0

	fake_view.backspace()

	mut lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"This is a sentence,it is in fact the first sentence."
	]

	assert fake_view.cursor.pos.x == 19
	assert fake_view.cursor.pos.y == 0

	fake_view.backspace()

	lines = fake_view.buffer.str().split("\n")
	assert lines == [
		"This is a sentenceit is in fact the first sentence."
	]

	assert fake_view.cursor.pos.x == 18
	assert fake_view.cursor.pos.y == 0
}

fn test_backspace_does_nothing_if_at_start_of_the_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("This is a sentence, it is in fact the first sentence.")

	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 0

	fake_view.backspace()

	mut lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"This is a sentence, it is in fact the first sentence."
	]

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 0
}

fn test_backspace_removing_newlines() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("This is the first sentence.\nThis is the second sentence.")

	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 1

	mut lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"This is the first sentence.",
		"This is the second sentence."
	]

	fake_view.backspace()

	lines = fake_view.buffer.str().split("\n")
	assert lines == [
		"This is the first sentence.This is the second sentence."
	]

	assert fake_view.cursor.pos.x == 27
	assert fake_view.cursor.pos.y == 0

	fake_view.backspace()

	lines = fake_view.buffer.str().split("\n")
	assert lines == [
		"This is the first sentenceThis is the second sentence."
	]

	assert fake_view.cursor.pos.x == 26
	assert fake_view.cursor.pos.y == 0
}

fn test_left_arrow_at_start_of_sentence() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("\nsingle line of text!\n")

	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 1

	fake_view.left()

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 1
}

fn test_left_arrow_at_end_of_sentence() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("\nsingle line of text!\n")

	fake_view.cursor.pos.x = 19
	fake_view.cursor.pos.y = 1

	fake_view.left()

	assert fake_view.cursor.pos.x == 18
	assert fake_view.cursor.pos.y == 1
}

fn test_right_arrow_at_start_of_sentence() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("\nsingle line of text!\n")

	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 1

	fake_view.right()

	assert fake_view.cursor.pos.x == 1
	assert fake_view.cursor.pos.y == 1
}

fn test_right_arrow_at_end_of_sentence() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("\nsingle line of text!\n")

	fake_view.cursor.pos.x = 19
	fake_view.cursor.pos.y = 1

	fake_view.right()

	assert fake_view.cursor.pos.x == 20
	assert fake_view.cursor.pos.y == 1
}

fn test_h_at_start_of_sentence() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("\nsingle line of text!\n")

	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 1

	fake_view.h()

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 1
}

fn test_h_at_end_of_sentence() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("\nsingle line of text!\n")

	fake_view.cursor.pos.x = 19
	fake_view.cursor.pos.y = 1

	fake_view.h()

	assert fake_view.cursor.pos.x == 18
	assert fake_view.cursor.pos.y == 1
}

fn test_l_at_start_of_sentence() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("\nsingle line of text!\n")

	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 1

	fake_view.l()

	assert fake_view.cursor.pos.x == 1
	assert fake_view.cursor.pos.y == 1
}

fn test_l_at_end_of_sentence() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("\nsingle line of text!\n")

	fake_view.cursor.pos.x = 19
	fake_view.cursor.pos.y = 1

	fake_view.l()

	assert fake_view.cursor.pos.x == 20
	assert fake_view.cursor.pos.y == 1
}

fn test_j_at_start_of_sentence() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("\nsingle line of text!\n")

	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 1

	fake_view.j()

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 2
}

fn test_j_in_middle_of_sentence_retain_x_pos_second_line_is_long_enough() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("\nFirst line of multiple lines of text!\nSecond line of multiple")

	fake_view.cursor.pos.x = 10
	fake_view.cursor.pos.y = 1

	fake_view.j()

	assert fake_view.cursor.pos.x == 10
	assert fake_view.cursor.pos.y == 2
}

fn test_j_in_middle_of_sentence_does_not_retain_x_pos_second_line_is_too_short() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("\nFirst line of multiple lines of text!\nSecond")

	fake_view.cursor.pos.x = 10
	fake_view.cursor.pos.y = 1

	fake_view.j()

	assert fake_view.cursor.pos.x == 5
	assert fake_view.cursor.pos.y == 2
}

fn test_k_at_start_of_sentence() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("\nsingle line of text!\n")

	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 2

	fake_view.k()

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 1
}

fn test_k_in_middle_of_sentence_retain_x_pos_second_line_is_long_enough() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("\nFirst line of multiple lines of text!\nSecond line of multiple")

	fake_view.cursor.pos.x = 10
	fake_view.cursor.pos.y = 2

	fake_view.k()

	assert fake_view.cursor.pos.x == 10
	assert fake_view.cursor.pos.y == 1
}

fn test_k_in_middle_of_sentence_does_not_retain_x_pos_second_line_is_too_short() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("\nFirst\nSecond line of multiple lines of text!")

	fake_view.cursor.pos.x = 10
	fake_view.cursor.pos.y = 2

	fake_view.k()

	assert fake_view.cursor.pos.x == 4
	assert fake_view.cursor.pos.y == 1
}

fn test_jump_cursor_up_to_next_blank_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap([
		"# Top of the file",
		"",
		"Some fake block of text which may or may not be",
		"more than one line in size, so it can be used for",
		"this testing scenario",
		"",
		"this is the last line of the document"
	].join("\n"))

	fake_view.cursor.pos.y = 4
	fake_view.jump_cursor_up_to_next_blank_line()

	assert fake_view.cursor.pos.y == 1
}

fn test_jump_cursor_down_to_next_blank_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap([
		"# Top of the file",
		"",
		"Some fake block of text which may or may not be",
		"more than one line in size, so it can be used for",
		"this testing scenario",
		"",
		"this is the last line of the document"
	].join("\n"))

	fake_view.cursor.pos.y = 2
	fake_view.jump_cursor_down_to_next_blank_line()

	assert fake_view.cursor.pos.y == 5
}

fn test_tab_inserts_a_tab_not_spaces() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		config: workspace.Config{
			insert_tabs_not_spaces: true
		}
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("1. first line")

	fake_view.cursor.pos.x = 9
	fake_view.cursor.pos.y = 0

	fake_view.insert_tab()

	assert fake_view.buffer.str().split("\n") == [
		"1. first \tline"
	]
}

fn test_tab_inserts_spaces_not_a_tab() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		config: workspace.Config{
			insert_tabs_not_spaces: false
		}
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("1. first line")

	fake_view.cursor.pos.x = 9
	fake_view.cursor.pos.y = 0

	fake_view.insert_tab()

	assert fake_view.buffer.str().split("\n") == [
		"1. first     line"
	]
}

fn test_find_end_of_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
		config: workspace.Config{
			insert_tabs_not_spaces: false
		}
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("1. first line\n2. second line and slightly longer!")

	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 0

	mut x_pos := fake_view.buffer.find_end_of_line(buffer.Pos{ y: fake_view.cursor.pos.y }) or { 0 }
	assert x_pos == 13

	fake_view.cursor.pos.y = 1
	x_pos = fake_view.buffer.find_end_of_line(buffer.Pos{ y: fake_view.cursor.pos.y }) or { 0 }
	assert x_pos == 35
}

