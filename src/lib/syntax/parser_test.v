module syntax

// NOTE(tauraamui) [06/04/2025]:
//	this test should really be defined to expect more contents to be resolved
//	in token form, i.e, it should expect the comment symbols, and the comment contents
//	itself to be returned as correctly typed tokens, but I like to add the new functionality
//	and then update the test to reflect these changes afterwards
//
//	whilst not true tdd I personally find this extremely useful, as it prevents me from just
//	trying to satisfy the pre-determined behaviour as defined by the test, which might be wrong
//	in a subtle way that I might not have noticed until doing the implementation
fn test_parser_half_line_non_comment_half_line_commented() {
	code := "fn main() { // this main does stuff"

	mut parser := Parser{}
	lines := code.split("\n")
	for i, line in lines {
		parser.parse_line(i, line)
	}

	assert lines.len == 1
	line_tokens := parser.get_line_tokens(0)

	assert line_tokens.len == 6
	assert extract_token_contents(lines[0], line_tokens[0]) == "fn"
	assert extract_token_contents(lines[0], line_tokens[1]) == " "
	assert extract_token_contents(lines[0], line_tokens[2]) == "main"
	assert extract_token_contents(lines[0], line_tokens[3]) == "()"
	assert extract_token_contents(lines[0], line_tokens[4]) == " "
	assert extract_token_contents(lines[0], line_tokens[5]) == "{"
}

fn extract_token_contents(data string, token Token) string {
	return data[token.start..token.end].str()
}

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

	assert lines.len == 10
	assert parser.get_line_tokens(0) == []
	assert_line_1_tokens(lines[1], parser.get_line_tokens(1))
	assert_line_2_tokens(lines[2], parser.get_line_tokens(2))
	assert_line_3_tokens(lines[3], parser.get_line_tokens(3))
	assert_line_4_tokens(lines[4], parser.get_line_tokens(4))
	assert_line_5_tokens(lines[5], parser.get_line_tokens(5))
	assert_line_6_tokens(lines[6], parser.get_line_tokens(6))
	assert_line_7_tokens(lines[7], parser.get_line_tokens(7))
	assert_line_8_tokens(lines[8], parser.get_line_tokens(8))
	assert parser.get_line_tokens(9) == []
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

	assert line_1[line_1_token_0.start..line_1_token_0.end] == "//"
	assert line_1_token_0.t_type == .other

	assert line_1[line_1_token_1.start..line_1_token_1.end] == " "
	assert line_1_token_1.t_type == .whitespace

	assert line_1[line_1_token_2.start..line_1_token_2.end] == "This"
	assert line_1_token_2.t_type == .identifier

	assert line_1[line_1_token_3.start..line_1_token_3.end] == " "
	assert line_1_token_3.t_type == .whitespace

	assert line_1[line_1_token_4.start..line_1_token_4.end] == "is"
	assert line_1_token_4.t_type == .identifier

	assert line_1[line_1_token_5.start..line_1_token_5.end] == " "
	assert line_1_token_5.t_type == .whitespace

	assert line_1[line_1_token_6.start..line_1_token_6.end] == "a"
	assert line_1_token_6.t_type == .identifier

	assert line_1[line_1_token_7.start..line_1_token_7.end] == " "
	assert line_1_token_7.t_type == .whitespace

	assert line_1[line_1_token_8.start..line_1_token_8.end] == "comment"
	assert line_1_token_8.t_type == .identifier
}

fn assert_line_2_tokens(line_2 string, line_2_tokens []Token) {
	assert line_2_tokens.len == 6
	line_2_token_0 := line_2_tokens[0]
	line_2_token_1 := line_2_tokens[1]
	line_2_token_2 := line_2_tokens[2]
	line_2_token_3 := line_2_tokens[3]
	line_2_token_4 := line_2_tokens[4]
	line_2_token_5 := line_2_tokens[5]

	assert line_2[line_2_token_0.start..line_2_token_0.end] == "fn"
	assert line_2_token_0.t_type == .identifier

	assert line_2[line_2_token_1.start..line_2_token_1.end] == " "
	assert line_2_token_1.t_type == .whitespace

	assert line_2[line_2_token_2.start..line_2_token_2.end] == "main"
	assert line_2_token_2.t_type == .identifier

	assert line_2[line_2_token_3.start..line_2_token_3.end] == "()"
	assert line_2_token_3.t_type == .other

	assert line_2[line_2_token_4.start..line_2_token_4.end] == " "
	assert line_2_token_4.t_type == .whitespace

	assert line_2[line_2_token_5.start..line_2_token_5.end] == "{"
	assert line_2_token_5.t_type == .other
}

fn assert_line_3_tokens(line_3 string, line_3_tokens []Token) {
	assert line_3_tokens.len == 2
	line_3_token_0 := line_3_tokens[0]
	line_3_token_1 := line_3_tokens[1]

	assert line_3[line_3_token_0.start..line_3_token_0.end] == "\t"
	assert line_3_token_0.t_type == .whitespace

	assert line_3[line_3_token_1.start..line_3_token_1.end] == "/*"
	assert line_3_token_1.t_type == .other
}

fn assert_line_4_tokens(line_4 string, line_4_tokens []Token) {
	assert line_4_tokens.len == 6
	line_4_token_0 := line_4_tokens[0]
	line_4_token_1 := line_4_tokens[1]
	line_4_token_2 := line_4_tokens[2]
	line_4_token_3 := line_4_tokens[3]
	line_4_token_4 := line_4_tokens[4]
	line_4_token_5 := line_4_tokens[5]

	assert line_4[line_4_token_0.start..line_4_token_0.end] == "\t "
	assert line_4_token_0.t_type == .whitespace

	assert line_4[line_4_token_1.start..line_4_token_1.end] == "*"
	assert line_4_token_1.t_type == .other

	assert line_4[line_4_token_2.start..line_4_token_2.end] == " "
	assert line_4_token_2.t_type == .whitespace

	assert line_4[line_4_token_3.start..line_4_token_3.end] == "Block"
	assert line_4_token_3.t_type == .identifier

	assert line_4[line_4_token_4.start..line_4_token_4.end] == " "
	assert line_4_token_4.t_type == .whitespace

	assert line_4[line_4_token_5.start..line_4_token_5.end] == "comment"
	assert line_4_token_5.t_type == .identifier
}

fn assert_line_5_tokens(line_5 string, line_5_tokens []Token) {
	assert line_5_tokens.len == 2
	line_5_token_0 := line_5_tokens[0]
	line_5_token_1 := line_5_tokens[1]

	assert line_5[line_5_token_0.start..line_5_token_0.end] == "\t "
	assert line_5_token_0.t_type == .whitespace

	assert line_5[line_5_token_1.start..line_5_token_1.end] == "*/"
	assert line_5_token_1.t_type == .other
}

fn assert_line_6_tokens(line_6 string, line_6_tokens []Token) {
	assert line_6_tokens.len == 10
	line_6_token_0 := line_6_tokens[0]
	line_6_token_1 := line_6_tokens[1]
	line_6_token_2 := line_6_tokens[2]
	line_6_token_3 := line_6_tokens[3]
	line_6_token_4 := line_6_tokens[4]
	line_6_token_5 := line_6_tokens[5]
	line_6_token_6 := line_6_tokens[6]
	line_6_token_7 := line_6_tokens[7]
	line_6_token_8 := line_6_tokens[8]
	line_6_token_9 := line_6_tokens[9]

	assert line_6[line_6_token_0.start..line_6_token_0.end] == "\t"
	assert line_6_token_0.t_type == .whitespace

	assert line_6[line_6_token_1.start..line_6_token_1.end] == "random"
	assert line_6_token_1.t_type == .identifier

	assert line_6[line_6_token_2.start..line_6_token_2.end] == "_"
	assert line_6_token_2.t_type == .other

	assert line_6[line_6_token_3.start..line_6_token_3.end] == "x"
	assert line_6_token_3.t_type == .identifier

	assert line_6[line_6_token_4.start..line_6_token_4.end] == "_"
	assert line_6_token_4.t_type == .other

	assert line_6[line_6_token_5.start..line_6_token_5.end] == "int"
	assert line_6_token_5.t_type == .identifier

	assert line_6[line_6_token_6.start..line_6_token_6.end] == " "
	assert line_6_token_6.t_type == .whitespace

	assert line_6[line_6_token_7.start..line_6_token_7.end] == ":="
	assert line_6_token_7.t_type == .other

	assert line_6[line_6_token_8.start..line_6_token_8.end] == " "
	assert line_6_token_8.t_type == .whitespace

	assert line_6[line_6_token_9.start..line_6_token_9.end] == "10"
	assert line_6_token_9.t_type == .number
}

fn assert_line_7_tokens(line_7 string, line_7_tokens []Token) {
	assert line_7_tokens.len == 8
	line_7_token_0 := line_7_tokens[0]
	line_7_token_1 := line_7_tokens[1]
	line_7_token_2 := line_7_tokens[2]
	line_7_token_3 := line_7_tokens[3]
	line_7_token_4 := line_7_tokens[4]
	line_7_token_5 := line_7_tokens[5]
	line_7_token_6 := line_7_tokens[6]
	line_7_token_7 := line_7_tokens[7]

	assert line_7[line_7_token_0.start..line_7_token_0.end] == "\t"
	assert line_7_token_0.t_type == .whitespace

	assert line_7[line_7_token_1.start..line_7_token_1.end] == "return"
	assert line_7_token_1.t_type == .identifier

	assert line_7[line_7_token_2.start..line_7_token_2.end] == " "
	assert line_7_token_2.t_type == .whitespace

	assert line_7[line_7_token_3.start..line_7_token_3.end] == "random"
	assert line_7_token_3.t_type == .identifier

	assert line_7[line_7_token_4.start..line_7_token_4.end] == "_"
	assert line_7_token_4.t_type == .other

	assert line_7[line_7_token_5.start..line_7_token_5.end] == "x"
	assert line_7_token_5.t_type == .identifier

	assert line_7[line_7_token_6.start..line_7_token_6.end] == "_"
	assert line_7_token_6.t_type == .other

	assert line_7[line_7_token_7.start..line_7_token_7.end] == "int"
	assert line_7_token_7.t_type == .identifier
}

fn assert_line_8_tokens(line_8 string, line_8_tokens []Token) {
	assert line_8_tokens.len == 1
	line_8_token_0 := line_8_tokens[0]

	assert line_8[line_8_token_0.start..line_8_token_0.end] == "}"
	assert line_8_token_0.t_type == .other
}

