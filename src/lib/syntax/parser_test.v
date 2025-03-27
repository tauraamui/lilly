module syntax

fn test_parser_block_of_code_one() {
	code := "
// This is a comment
fn main() {
	/*
	 * Block comment
	 */
	let x = 10
	return x
}
"

	mut parser := Parser{}

	code_lines := code.split("\n")

	parser.parse_line(code_lines[0])
	assert parser.get_line_tokens(0) == []

	parser.parse_line(code_lines[1])
	assert parser.get_line_tokens(1) == [Token{
		start: 0
		t_type: .comment
		data: [`/`, `/`, ` `, `T`, `h`, `i`, `s`, ` `, `i`, `s`, ` `, `a`, ` `, `c`, `o`, `m`, `m`, `e`, `n`, `t`]
	}]

	parser.parse_line(code_lines[2])
	mut line_tokens := parser.get_line_tokens(2)
	assert line_tokens[0] == Token{
		start: 0, t_type: .identifier, data: [`f`, `n`]
	}
	assert line_tokens[1] == Token{ start: 2, t_type: .whitespace, data: [` `] }
	assert line_tokens[2] == Token{
		start: 3, t_type: .identifier, data: [`m`, `a`, `i`, `n`]
	}
	assert line_tokens[3] == Token{ start: 7, t_type: .other, data: [`(`] }
	assert line_tokens[4] == Token{ start: 8, t_type: .other, data: [`)`] }
	assert line_tokens[5] == Token{ start: 9, t_type: .whitespace, data: [` `] }
	assert line_tokens[6] == Token{ start: 10, t_type: .block_start, data: [`{`] }

	parser.parse_line(code_lines[3])
	line_tokens = parser.get_line_tokens(3)
	assert line_tokens[0] == Token{ start: 0, t_type: .whitespace, data: [`\t`] }
	assert line_tokens[1] == Token{ start: 1, t_type: .comment_start, data: [`/`, `*`] }

	assert 1 == 9
}

