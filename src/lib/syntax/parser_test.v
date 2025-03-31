module syntax

/*
fn test_parser_manual() {
	code := "
// This is a comment
fn main() {
	/*
	 * Block comment
	 */
	random_x_int := 10
	return random_x_int
}
"

	mut parser := Parser{}

	code_lines := code.split("\n")

	for i, code_line in code_lines {
		code_line_chars := code_line.runes()
		parser.parse_line(code_line)
		line_tokens := parser.get_line_tokens(i)
		for j, token in line_tokens {
			print("${code_line_chars[token.start..token.end].string()}")
			if j + 1 == line_tokens.len {
				println("")
			}
		}
		// println("LINE ${i} tokens ${parser.get_line_tokens(i)}")
		// println(parser.tokens)
	}

	assert 1 == 3
}
*/

fn test_parser_block_of_code_one() {
	code := "
// This is a comment
fn main() {
	/*
	 * Block comment
	 */
	random_x_int := 10
	return random_x_int
}
"

	mut parser := Parser{}
	lines := code.split("\n")
	for i, line in lines {
		parser.parse_line(i, line)
	}

	assert parser.get_line_tokens(0) == []
	line_1_tokens := parser.get_line_tokens(1)

	line_1_token_0 := line_1_tokens[0]
	line_1_token_1 := line_1_tokens[1]
	line_1_token_2 := line_1_tokens[2]
	line_1_token_3 := line_1_tokens[3]
	line_1_token_4 := line_1_tokens[4]

	line_1_token_0_data := lines[1][line_1_token_0.start..line_1_token_0.end]
	line_1_token_1_data := lines[1][line_1_token_1.start..line_1_token_1.end]
	line_1_token_2_data := lines[1][line_1_token_2.start..line_1_token_2.end]
	line_1_token_3_data := lines[1][line_1_token_3.start..line_1_token_3.end]
	line_1_token_4_data := lines[1][line_1_token_4.start..line_1_token_4.end]

	// NOTE(tauraamui) [31/03/2025]: for some reason we cannot assert directly against a
	//                               string slice like this without v converting it into a string
	//                               literal
	assert line_1_token_0_data == "//"
	assert line_1_token_0.t_type == .other
	assert line_1_token_1_data == " "
	assert line_1_token_1.t_type == .whitespace
	assert line_1_token_2_data == "This"
	assert line_1_token_2.t_type == .other
	assert line_1_token_3_data == " "
	assert line_1_token_3.t_type == .whitespace
	assert line_1_token_4_data == "is"
	assert line_1_token_4.t_type == .other
}

