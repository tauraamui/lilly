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

fn test_dd_deletes_current_line_at_start_of_doc() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.buffer.lines = ["1. first line", "2. second line", "3. third line", "4. forth line"]
	fake_view.cursor.pos.y = 0

	fake_view.d()
	fake_view.d()

	assert fake_view.buffer.lines == ["2. second line", "3. third line", "4. forth line"]
	assert fake_view.y_lines == ["1. first line"]
}

fn test_dd_deletes_current_line_in_middle_of_doc() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.buffer.lines = ["1. first line", "2. second line", "3. third line", "4. forth line"]
	fake_view.cursor.pos.y = 2

	fake_view.d()
	fake_view.d()

	assert fake_view.buffer.lines == ["1. first line", "2. second line", "4. forth line"]
	assert fake_view.cursor.pos.y == 2
	assert fake_view.y_lines == ["3. third line"]
}

fn test_dd_deletes_current_line_at_end_of_doc() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	// manually set the "document" contents
	fake_view.buffer.lines = ["1. first line", "2. second line", "3. third line"]
	// ensure the cursor is set to sit on the last line
	fake_view.cursor.pos.y = fake_view.buffer.lines.len

	// invoke dd
	fake_view.d()
	fake_view.d()

	assert fake_view.buffer.lines == ["1. first line", "2. second line"]
	assert fake_view.cursor.pos.y == 1
	assert fake_view.y_lines == ["3. third line"]
}

fn test_o_inserts_sentance_line() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	// manually set the "document" contents
	fake_view.buffer.lines = ["1. first line", "2. second line"]
	// ensure cursor is set to sit on the first line
	fake_view.cursor.pos.y = 0

	// invoke the 'o' command
	fake_view.o()

	assert fake_view.mode == .insert
	assert fake_view.buffer.lines == ["1. first line", "", "2. second line"]
	assert fake_view.cursor.pos.y == 1
}

fn test_o_inserts_sentance_line_end_of_document() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	// manually set the "document" contents
	fake_view.buffer.lines = ["1. first line", "2. second line"]
	// ensure cursor is set to sit on the second line
	fake_view.cursor.pos.y = 1

	// invoke the 'o' command
	fake_view.o()

	assert fake_view.mode == .insert
	assert fake_view.buffer.lines == ["1. first line", "2. second line", ""]
	assert fake_view.cursor.pos.y == 2
}

fn test_o_inserts_line_and_auto_indents() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	// manually set the "document" contents
	fake_view.buffer.lines = ["	1. first line"]
	// ensure cursor is set to sit on the first line
	fake_view.cursor.pos.y = 0

	// invoke the 'o' command
	fake_view.o()

	assert fake_view.mode == .insert
	assert fake_view.buffer.lines == ["	1. first line", "	"]
	assert fake_view.cursor.pos.y == 1
}

fn test_o_auto_indents_but_clears_if_nothing_added_to_line() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	// manually set the "document" contents
	fake_view.buffer.lines = ["	1. first line"]
	// ensure cursor is set to sit on the first line
	fake_view.cursor.pos.y = 0

	// invoke the 'o' command
	fake_view.o()
	fake_view.escape()

	assert fake_view.mode == .normal
	assert fake_view.buffer.lines == ["	1. first line", ""]
	assert fake_view.cursor.pos.y == 0 // cursor y set back to selection start pos
}

fn test_resolve_whitespace_prefix_on_line_with_text() {
	test_line := "    4 spaces precede this text"
	assert resolve_whitespace_prefix(test_line) == "    "
}

fn test_resolve_whitespace_prefix_on_line_with_no_text() {
	test_line_with_just_4_spaces := "    "
	assert resolve_whitespace_prefix(test_line_with_just_4_spaces).len == 4
}

fn test_v_toggles_visual_mode_and_starts_selection() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	// manually set the "document" contents
	fake_view.buffer.lines = ["1. first line"]
	// ensure cursor is set to sit on sort of in the middle of the first line
	fake_view.cursor.pos.y = 0
	fake_view.cursor.pos.x = 6

	// invoke the 'v' command
	fake_view.v()

	assert fake_view.mode == .visual
	assert fake_view.cursor.selection_active()
	assert fake_view.cursor.selection_start == Pos{ 6, 0 }
}

fn test_enter_moves_trailing_segment_to_next_line_and_moves_cursor_in_front() {
	mut fake_view := View{ log: unsafe { nil }, mode: .insert }
	// manually set the "document" contents
	fake_view.buffer.lines = [
		"1. first line with some trailing content"
	]

	fake_view.cursor.pos.x = 8
	fake_view.cursor.pos.y = 0

	fake_view.enter()

	assert fake_view.buffer.lines == [
		"1. first",
		" line with some trailing content"
	]
	assert fake_view.cursor.pos.x == 0
}

fn test_enter_moves_trailing_segment_to_next_line_and_moves_cursor_to_past_prefix_whitespace() {
	mut fake_view := View{ log: unsafe { nil }, mode: .insert }
	fake_view.buffer.lines = [
		"    1. first line with whitespace prefix"
	]

	fake_view.cursor.pos.x = 10
	fake_view.cursor.pos.y = 0

	fake_view.enter()

	assert fake_view.buffer.lines == [
		"    1. fir",
		"    st line with whitespace prefix"
	]
	assert fake_view.cursor.pos.x == 4
}

fn test_enter_inserts_line_at_cur_pos_and_auto_indents() {
	mut fake_view := View{ log: unsafe { nil }, mode: .insert }
	// manually set the "document" contents
	fake_view.buffer.lines = ["	indented first line"]
	// ensure cursor is set to sit on the first line
	fake_view.cursor.pos.y = 0
	// ensure cursor is set to sit on the end of the line
	fake_view.cursor.pos.x = fake_view.buffer.lines[fake_view.cursor.pos.y].len

	// invoke enter
	fake_view.enter()

	assert fake_view.buffer.lines == ["	indented first line", "	"]
}

fn test_enter_auto_indents_but_clears_if_nothing_added_to_line() {
	mut fake_view := View{ log: unsafe { nil }, mode: .insert }
	// manually set the "document" contents
	fake_view.buffer.lines = ["	indented first line"]
	// ensure cursor is set to sit on the first line
	fake_view.cursor.pos.y = 0
	// ensure cursor is set to sit on the end of the line
	fake_view.cursor.pos.x = fake_view.buffer.lines[fake_view.cursor.pos.y].len

	// invoke enter
	fake_view.enter()
	assert fake_view.buffer.lines == ["	indented first line", "	"]

	fake_view.enter()
	assert fake_view.buffer.lines == ["	indented first line", "", ""]
}

fn test_backspace_deletes_char_from_end_of_sentance() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	// manually set the "document" contents
	fake_view.buffer.lines = ["single line of text!"]
	// ensure cursor is set to sit on the first line
	fake_view.cursor.pos.y = 0
	fake_view.mode = .insert
	fake_view.cursor.pos.x = fake_view.buffer.lines[fake_view.cursor.pos.y].len

	// invoke backspace
	fake_view.backspace()
	assert fake_view.buffer.lines == ["single line of text"]

	// invoke backspace
	fake_view.backspace()
	assert fake_view.buffer.lines == ["single line of tex"]
}

fn test_backspace_deletes_char_from_start_of_sentance() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.mode = .insert

	// manually set the "document" contents
	fake_view.buffer.lines = ["", "single line of text!"]
	// ensure cursor is set to sit on the second line
	fake_view.cursor.pos.y = 1
	// ensure the cursor is set to sit on the second char of the line
	fake_view.cursor.pos.x = 1

	// invoke backspace
	fake_view.backspace()
	assert fake_view.buffer.lines == ["", "ingle line of text!"]
}

fn test_backspace_moves_line_up_to_previous_line() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.mode = .insert

	// manually set the document contents
	fake_view.buffer.lines = ["", "single line of text!"]
	// ensure cursor is set to sit on the second line
	fake_view.cursor.pos.y = 1
	// ensure the cursor is set to sit on the second char of the line
	fake_view.cursor.pos.x = 0

	// invoke backspace
	fake_view.backspace()
	assert fake_view.buffer.lines == ["single line of text!"]
}

fn test_backspace_moves_line_up_to_end_of_previous_line() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.mode = .insert

	// manually set the document contents
	fake_view.buffer.lines = ["i am the first line", "single line of text!"]
	// ensure cursor is set to sit on the second line
	fake_view.cursor.pos.y = 1
	// ensure the cursor is set to sit on the first char of the line
	fake_view.cursor.pos.x = 0

	// invoke backspace
	fake_view.backspace()
	assert fake_view.buffer.lines == ["i am the first linesingle line of text!"]
	assert fake_view.cursor.pos.x == 19
	assert fake_view.cursor.pos.y == 0
	assert fake_view.buffer.lines[fake_view.cursor.pos.y][fake_view.cursor.pos.x].ascii_str() == "s"
}

fn test_backspace_at_start_of_sentance_first_line_does_nothing() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.mode = .insert

	// manually set the document contents
	fake_view.buffer.lines = ["single line of text!", ""]
	// ensure cursor is set to sit on the first line
	fake_view.cursor.pos.y = 0
	// ensure cursor is set to sit on the first char of the line
	fake_view.cursor.pos.x = 0

	// invoke backspace
	fake_view.backspace()
	assert fake_view.buffer.lines == ["single line of text!", ""]
}

fn test_left_arrow_at_start_of_sentence_in_insert_mode() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.mode = .insert

	// manually set the document contents
	fake_view.buffer.lines = ["", "single line of text!", ""]
	// ensure cursor is set to sit on the second line
	fake_view.cursor.pos.y = 1
	// ensure cursor is set to sit on the first char of the line
	fake_view.cursor.pos.x = 0

	// invoke left
	fake_view.left()

	assert fake_view.cursor.pos.x == 0
}

fn test_right_arrow_at_start_of_sentence_in_insert_mode() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.mode = .insert

	// manually set the documents contents
	fake_view.buffer.lines = ["", "single line of text!", ""]
	// ensure cursor is set to sit on the second line
	fake_view.cursor.pos.y = 1
	// ensure cursor is set to sit on the first char of the line
	fake_view.cursor.pos.x = 0

	// invoke right
	fake_view.right()

	assert fake_view.cursor.pos.x == 1
}

fn test_left_arrow_at_end_of_sentence_in_insert_mode() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.mode = .insert

	// manually set the documents contents
	fake_view.buffer.lines = ["", "single line of text!", ""]
	// ensure cursor is set to sit on the second line
	fake_view.cursor.pos.y = 1
	// ensure the cursor is set to sit on the last char of the line
	fake_view.cursor.pos.x = fake_view.buffer.lines[fake_view.cursor.pos.y].len

	// invoke left
	fake_view.left()

	assert fake_view.cursor.pos.x == 19
}

fn test_right_arrow_at_end_of_sentence_in_insert_mode() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.mode = .insert

	// manually set the documents contents
	fake_view.buffer.lines = ["", "single line of text!", ""]
	// ensure cursor is set to sit on the second line
	fake_view.cursor.pos.y = 1
	// ensure the cursor is set to sit on the last char of the line
	fake_view.cursor.pos.x = fake_view.buffer.lines[fake_view.cursor.pos.y].len

	// invoke right
	fake_view.right()

	assert fake_view.cursor.pos.x == 20
}

fn test_visual_insert_mode_and_delete_in_place() {
	mut fake_view := View{ log: unsafe{ nil }, mode: .normal }

	// manually set the documents contents
	fake_view.buffer.lines = ["1. first line", "2. second line", "3. third line", "4. forth line"]
	// ensure cursor is set to sit on the start of second line
	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 1

	fake_view.v()
	fake_view.visual_d(true)

	assert fake_view.mode == .normal
	assert fake_view.buffer.lines == ["1. first line", "3. third line", "4. forth line"]
}

fn test_visual_insert_mode_selection_move_down_once_and_delete() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }

	// manually set the documents contents
	fake_view.buffer.lines = ["1. first line", "2. second line", "3. third line", "4. forth line"]
	// ensure cursor is set to sit on the start of second line
	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 1

	fake_view.v()
	fake_view.j()
	fake_view.visual_d(true)

	assert fake_view.mode == .normal
	assert fake_view.buffer.lines == ["1. first line", "4. forth line"]
}

fn test_visual_selection_copy() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }

	// manually set the documents contents
	fake_view.buffer.lines = [
		"1. first line",
		"2. second line",
		"3. third line",
		"4. forth line",
		"5. fifth line"
	]

	assert fake_view.y_lines == []

	// ensure cursor is set to sit on second line
	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 1

	fake_view.v()
	fake_view.j()
	fake_view.visual_y()

	assert fake_view.y_lines == [
		"2. second line",
		"3. third line"
	]
}

fn test_paste() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }

	// manually set the documents contents
	fake_view.buffer.lines = [
		"1. first line",
		"2. second line",
		"3. third line",
		"4. forth line",
		"5. fifth line"
	]

	fake_view.y_lines = ["some new random contents", "with multiple lines"]

	// ensure cursor is set to sit on second line
	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 1

	fake_view.p()

	assert fake_view.buffer.lines == [
		"1. first line",
		"2. second line",
		"some new random contents",
		"with multiple lines",
		"3. third line",
		"4. forth line",
		"5. fifth line"
	]
}

fn test_visual_paste() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }

	// manually set the documents contents
	fake_view.buffer.lines = [
		"1. first line",
		"2. second line",
		"3. third line",
		"4. forth line",
		"5. fifth line"
	]

	fake_view.y_lines = ["some new random contents", "with multiple lines"]

	// ensure cursor is set to sit on second line
	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 1
	fake_view.v()
	fake_view.j()

	fake_view.visual_p()

	assert fake_view.buffer.lines == [
		"1. first line",
		"some new random contents",
		"with multiple lines",
		"4. forth line",
		"5. fifth line"
	]
}

fn test_search_is_toggled() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }

	fake_view.search()

	assert fake_view.mode == .search
}

fn test_search_within_for_single_line() {
	mut fake_search := Search{ to_find: "/efg" }
	fake_search.find(["abcdefg"])
	assert fake_search.finds[0] == [4, 7]
	result := fake_search.next_find_pos() or { panic("") }
	assert result.start == 4
	assert result.end == 7
	assert result.line == 0
}

fn test_search_within_for_multiple_lines() {
	mut fake_search := Search{ to_find: "/redpanda" }
	fake_search.find([
		"This is a fake document that doesn't talk about anything.",
		"It might mention animals like bats, redpandas and goats, but that's all.",
		"Trees are where redpandas hang out, literally."
	])
	assert fake_search.finds[0] == []
	assert fake_search.finds[1] == [36, 44]
	assert fake_search.finds[2] == [16, 24]

	first_result := fake_search.next_find_pos() or { panic("") }
	assert first_result.start == 36
	assert first_result.end == 44
	assert first_result.line == 1

	second_result := fake_search.next_find_pos() or { panic("") }
	assert second_result.start == 16
	assert second_result.end == 24
	assert second_result.line == 2

	scrolled_back_around_result := fake_search.next_find_pos() or { panic("") }
	assert scrolled_back_around_result.start == 36
	assert scrolled_back_around_result.end == 44
	assert scrolled_back_around_result.line == 1
}

fn test_search_within_for_multiple_lines_multiple_matches_per_line() {
	mut fake_search := Search{ to_find: "/redpanda" }
	fake_search.find([
		"This is a fake document about redpandas, it mentions redpandas multiple times.",
		"Any animal like redpandas might be referred to more than once, who knows?"
	])

	assert fake_search.finds[0] == [30, 38, 53, 61]
	assert fake_search.finds[1] == [16, 24]

	first_result := fake_search.next_find_pos() or { panic("") }
	assert first_result.start == 30
	assert first_result.end == 38
	assert first_result.line == 0

	second_result := fake_search.next_find_pos() or { panic("") }
	assert second_result.start == 53
	assert second_result.end == 61
	assert second_result.line == 0

	third_result := fake_search.next_find_pos() or { panic("") }
	assert third_result.start == 16
	assert third_result.end == 24
	assert third_result.line == 1

	looped_back_first_result := fake_search.next_find_pos() or { panic("") }
	assert looped_back_first_result.start == 30
	assert looped_back_first_result.end == 38
	assert looped_back_first_result.line == 0
}

fn test_move_cursor_with_b_from_start_of_line_which_preceeds_a_blank_line() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.buffer.lines = ["1. first line", "", "3. third line"]

	fake_view.cursor.pos.x = 0
	fake_view.cursor.pos.y = 2

	fake_view.b()

	assert fake_view.cursor.pos.x == 0
	assert fake_view.cursor.pos.y == 1
}

fn test_jump_cursor_up_to_next_blank_line() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.buffer.lines = [
		"# Top of the file"
		"",
		"Some fake block of text which may or may not be",
		"more than one line in size, so it can be used for",
		"this testing scenario.",
		"",
		"this is the last line of the document"
	]

	fake_view.cursor.pos.y = 4
	assert "this testing scenario." == fake_view.buffer.lines[fake_view.cursor.pos.y]
	fake_view.jump_cursor_up_to_next_blank_line()
	assert "" == fake_view.buffer.lines[fake_view.cursor.pos.y]
	fake_view.jump_cursor_up_to_next_blank_line()
	assert "# Top of the file" == fake_view.buffer.lines[fake_view.cursor.pos.y]
}

fn test_jump_cursor_down_to_next_blank_line() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.buffer.lines = [
		"# Top of the file"
		"",
		"Some fake block of text which may or may not be",
		"more than one line in size, so it can be used for",
		"this testing scenario.",
		"",
		"this is the last line of the document"
	]

	fake_view.cursor.pos.y = 0
	assert "# Top of the file" == fake_view.buffer.lines[fake_view.cursor.pos.y]
	fake_view.jump_cursor_down_to_next_blank_line()
	assert "" == fake_view.buffer.lines[fake_view.cursor.pos.y]
	fake_view.jump_cursor_down_to_next_blank_line()
	assert "" == fake_view.buffer.lines[fake_view.cursor.pos.y]
	fake_view.jump_cursor_down_to_next_blank_line()
	assert "this is the last line of the document" == fake_view.buffer.lines[fake_view.cursor.pos.y]
}

fn test_calc_w_move_amount_simple_sentence_line() {
	// manually set the documents contents
	fake_line := "this is a line to test with"
	mut fake_cursor_pos := Pos{ x: 0 }

	mut amount := calc_w_move_amount(fake_cursor_pos, fake_line)
	assert amount == 5
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "i"

	amount = calc_w_move_amount(fake_cursor_pos, fake_line)
	assert amount == 3
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "a"
}

fn test_calc_w_move_amount_code_line() {
	// manually set the documents contents
	fake_line := "fn (mut view View) w() {"
	mut fake_cursor_pos := Pos{ x: 0 }

	mut amount := calc_w_move_amount(fake_cursor_pos, fake_line)
	assert amount == 3
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "("

	amount = calc_w_move_amount(fake_cursor_pos, fake_line)
	assert amount == 5
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "v"
}

fn test_calc_w_move_amount_indented_code_line() {
	// manually set the document contents
	fake_line := "		for i := 0; i < 100; i++ {"
	mut fake_cursor_pos := Pos{ x: 0 }

	mut amount := calc_w_move_amount(fake_cursor_pos, fake_line)
	assert amount == 2
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "f"

	amount = calc_w_move_amount(fake_cursor_pos, fake_line)
	assert amount == 4
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "i"
}

fn test_calc_e_move_amount_code_line() {
	// manually set the document contents
	fake_line := "status_green            = Color { 145, 237, 145 }"

	mut fake_cursor_pos := Pos{ x: 0 }

	mut amount := calc_e_move_amount(fake_cursor_pos, fake_line)
	assert amount == 11
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "n"

	amount = calc_e_move_amount(fake_cursor_pos, fake_line)
	assert amount == 13
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "="

	amount = calc_e_move_amount(fake_cursor_pos, fake_line)
	assert amount == 6
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "r"

	amount = calc_e_move_amount(fake_cursor_pos, fake_line)
	assert amount == 2
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "{"

	amount = calc_e_move_amount(fake_cursor_pos, fake_line)
	assert amount == 5
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == ","
}

fn test_calc_e_move_amount_word_with_leading_whitespace() {
	// manually set the document contents
	fake_line := "    this"
	mut fake_cursor_pos := Pos{ x: 0 }

	mut amount := calc_e_move_amount(fake_cursor_pos, fake_line)
	assert amount == 7
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "s"
}

fn test_calc_e_move_amount_two_words_with_leading_whitespace() {
	// manually set the document contents
	fake_line := "    this sentence"

	mut fake_cursor_pos := Pos{ x: 0 }

	mut amount := calc_e_move_amount(fake_cursor_pos, fake_line)
	assert amount == 7
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "s"

	amount = calc_e_move_amount(fake_cursor_pos, fake_line)
	assert amount == 9
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "e"

	amount = calc_e_move_amount(fake_cursor_pos, fake_line)
	assert amount == 0
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "e"
}

fn test_calc_e_move_amount_multiple_words_with_leading_whitespace() {
	fake_line := "    this sentence is a test for this test"

	mut fake_cursor_pos := Pos{ x: 0 }

	mut amount := calc_e_move_amount(fake_cursor_pos, fake_line)
	assert amount == 7
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "s"

	amount = calc_e_move_amount(fake_cursor_pos, fake_line)
	assert amount == 9
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "e"

	amount = calc_e_move_amount(fake_cursor_pos, fake_line)
	assert amount == 3
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "s"

	amount = calc_e_move_amount(fake_cursor_pos, fake_line)
	assert amount == 2
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "a"

	amount = calc_e_move_amount(fake_cursor_pos, fake_line)
	assert amount == 5
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "t"

	amount = calc_e_move_amount(fake_cursor_pos, fake_line)
	assert amount == 4
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "r"
}

fn test_calc_b_move_amount_code_line() {
	fake_line := "status_green            = Color { 145, 237, 145 }"

	mut fake_cursor_pos := Pos{ x: 42 }

	mut amount := calc_b_move_amount(fake_cursor_pos, fake_line)
	assert amount == 3
	fake_cursor_pos.x -= amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "2"

	amount = calc_b_move_amount(fake_cursor_pos, fake_line)
	assert amount == 5
	fake_cursor_pos.x -= amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "1"

	amount = calc_b_move_amount(fake_cursor_pos, fake_line)
	assert amount == 2
	fake_cursor_pos.x -= amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "{"

	amount = calc_b_move_amount(fake_cursor_pos, fake_line)
	assert amount == 6
	fake_cursor_pos.x -= amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "C"

	amount = calc_b_move_amount(fake_cursor_pos, fake_line)
	assert amount == 2
	fake_cursor_pos.x -= amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "="

	amount = calc_b_move_amount(fake_cursor_pos, fake_line)
	assert amount == 24
	fake_cursor_pos.x -= amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "s"

	amount = calc_b_move_amount(fake_cursor_pos, fake_line)
	assert amount == 0
	fake_cursor_pos.x -= amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "s"
}
