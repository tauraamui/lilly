module main

fn test_o_inserts_sentance_line() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.buffer.lines = ["1. first line", "2. second line"]

	fake_view.o()

	assert fake_view.mode == .insert
	assert fake_view.buffer.lines == ["1. first line", "", "2. second line"]
	assert fake_view.cursor.pos.y == 1
}

fn test_o_inserts_sentance_line_end_of_document() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.buffer.lines = ["1. first line", "2. second line"]
	fake_view.cursor.pos.y = 1

	fake_view.o()

	assert fake_view.mode == .insert
	assert fake_view.buffer.lines == ["1. first line", "2. second line", ""]
	assert fake_view.cursor.pos.y == 2
}

fn test_backspace_deletes_char_from_end_of_sentance() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.buffer.lines = ["single line of text!"]
	fake_view.cursor.pos.y = 0
	fake_view.mode = .insert
	fake_view.cursor.pos.x = fake_view.buffer.lines[fake_view.cursor.pos.y].len

	fake_view.backspace()
	assert fake_view.buffer.lines == ["single line of text"]

	fake_view.backspace()
	assert fake_view.buffer.lines == ["single line of tex"]
}

fn test_backspace_deletes_char_from_start_of_sentance() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.mode = .insert

	fake_view.buffer.lines = ["", "single line of text!"]
	fake_view.cursor.pos.y = 1
	fake_view.cursor.pos.x = 1

	fake_view.backspace()
	assert fake_view.buffer.lines == ["", "ingle line of text!"]
}

fn test_backspace_moves_line_up_to_previous_line() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.mode = .insert

	fake_view.buffer.lines = ["", "single line of text!"]
	fake_view.cursor.pos.y = 1
	fake_view.cursor.pos.x = 0

	fake_view.backspace()
	assert fake_view.buffer.lines == ["single line of text!"]
}

fn test_backspace_moves_line_up_to_end_of_previous_line() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.mode = .insert

	fake_view.buffer.lines = ["i am the first line", "single line of text!"]
	fake_view.cursor.pos.y = 1
	fake_view.cursor.pos.x = 0

	fake_view.backspace()
	assert fake_view.buffer.lines == ["i am the first linesingle line of text!"]
	assert fake_view.cursor.pos.x == 19
	assert fake_view.buffer.lines[0][fake_view.cursor.pos.x].ascii_str() == "s"
}

fn test_backspace_at_start_of_sentance_first_line_does_nothing() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.mode = .insert

	fake_view.buffer.lines = ["single line of text!", ""]
	fake_view.cursor.pos.y = 0
	fake_view.cursor.pos.x = 0

	fake_view.backspace()
	assert fake_view.buffer.lines == ["single line of text!", ""]
}

fn test_left_arrow_at_start_of_sentence_in_insert_mode() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.mode = .insert

	fake_view.buffer.lines = ["", "single line of text!", ""]
	fake_view.cursor.pos.y = 1
	fake_view.cursor.pos.x = 0

	fake_view.left()

	assert fake_view.cursor.pos.x == 0
}

fn test_right_arrow_at_start_of_sentence_in_insert_mode() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.mode = .insert

	fake_view.buffer.lines = ["", "single line of text!", ""]
	fake_view.cursor.pos.y = 1
	fake_view.cursor.pos.x = 0

	fake_view.right()

	assert fake_view.cursor.pos.x == 1
}

fn test_left_arrow_at_end_of_sentence_in_insert_mode() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.mode = .insert

	fake_view.buffer.lines = ["", "single line of text!", ""]
	fake_view.cursor.pos.y = 1
	fake_view.cursor.pos.x = fake_view.buffer.lines[fake_view.cursor.pos.y].len

	fake_view.left()

	assert fake_view.cursor.pos.x == 19
}

fn test_right_arrow_at_end_of_sentence_in_insert_mode() {
	mut fake_view := View{ log: unsafe { nil }, mode: .normal }
	fake_view.mode = .insert

	fake_view.buffer.lines = ["", "single line of text!", ""]
	fake_view.cursor.pos.y = 1
	fake_view.cursor.pos.x = fake_view.buffer.lines[fake_view.cursor.pos.y].len

	fake_view.right()

	assert fake_view.cursor.pos.x == 20
}

fn test_calc_w_move_amount_simple_sentence_line() {
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
	fake_line := "    this"
	mut fake_cursor_pos := Pos{ x: 0 }

	mut amount := calc_e_move_amount(fake_cursor_pos, fake_line)
	assert amount == 7
	fake_cursor_pos.x += amount
	assert fake_line[fake_cursor_pos.x].ascii_str() == "s"
}

fn test_calc_e_move_amount_two_words_with_leading_whitespace() {
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
