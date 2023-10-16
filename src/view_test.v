module main

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
}
