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

	assert_line_1_tokens(lines[1], line_1_tokens)
}

fn assert_line_1_tokens(line_1 string, line_1_tokens []Token) {
	assert line_1_tokens.len == 9
	line_1_token_0 := line_1_tokens[0]
	line_1_token_1 := line_1_tokens[1]
	line_1_token_2 := line_1_tokens[2]
	line_1_token_3 := line_1_tokens[3]
	line_1_token_4 := line_1_tokens[4]
	line_1_token_5 := line_1_tokens[5]
	line_1_token_6 := line_1_tokens[6]
	line_1_token_7 := line_1_tokens[7]
	line_1_token_8 := line_1_tokens[8]

	// NOTE(tauraamui) [31/03/2025]: for some reason we cannot assert directly against a
	//                               string slice like this without v converting it into a string
	//                               literal
	assert "${line_1[line_1_token_0.start..line_1_token_0.end]}" == "//"
	assert line_1_token_0.t_type == .other

	assert "${line_1[line_1_token_1.start..line_1_token_1.end]}" == " "
	assert line_1_token_1.t_type == .whitespace

	assert "${line_1[line_1_token_2.start..line_1_token_2.end]}" == "This"
	assert line_1_token_2.t_type == .other

	assert "${line_1[line_1_token_3.start..line_1_token_3.end]}" == " "
	assert line_1_token_3.t_type == .whitespace

	assert "${line_1[line_1_token_4.start..line_1_token_4.end]}" == "is"
	assert line_1_token_4.t_type == .other

	assert "${line_1[line_1_token_5.start..line_1_token_5.end]}" == " "
	assert line_1_token_5.t_type == .whitespace

	assert "${line_1[line_1_token_6.start..line_1_token_6.end]}" == "a"
	assert line_1_token_6.t_type == .other

	assert "${line_1[line_1_token_7.start..line_1_token_7.end]}" == " "
	assert line_1_token_7.t_type == .whitespace

	assert "${line_1[line_1_token_8.start..line_1_token_8.end]}" == "comment"
	assert line_1_token_8.t_type == .other
}


