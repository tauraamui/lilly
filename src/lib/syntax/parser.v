module syntax

// NOTE(tauraamui) [27/03/2025]: this is ... idk I just feel like trying to write something
//                               that feels comfier than trying to embed TS's parser.c and
//                               have a custom scanner thing

enum State {
	default
	in_block_comment
}

enum TokenType {
	keyword
	identifier
	operator
	string
	comment
	comment_start
	comment_end
	block_start
	block_end
	number
	whitespace
	other
}

pub struct Token {
	t_type TokenType
mut:
	data   []rune
	start  int
}

struct LineInfo {
	start_token_index int
	token_count       int
}

pub struct Parser {
mut:
	state         State
	pending_token ?Token
	tokens        []Token
	line_info     []LineInfo
}

fn (parser Parser) get_line_tokens(line_num int) []Token {
	if line_num < 0 || line_num >= parser.line_info.len {
		return []Token{}
	}
	line_info   := parser.line_info[line_num]
	start_index := line_info.start_token_index
	end_index   := start_index + line_info.token_count
	return parser.tokens[start_index..end_index]
}

pub fn (mut parser Parser) parse_line(line string) {
	mut start_token_index := parser.tokens.len
	mut token_count       := 0
	runes                 := line.runes()

	mut i := 0
	for i < runes.len {
		if parser.state == .in_block_comment {
			mut pending_token := parser.pending_token or { Token{ t_type: .comment, start: i } }
			if i + 1 < runes.len && runes[i] == `*` && runes[i + 1] == `/` {
				if pending_token.start < i {
					parser.tokens << pending_token
					token_count += 1
				}
				parser.tokens << Token{
					t_type: .comment_end
					data: [runes[i], runes[i + 1]]
					start: i
				}
				token_count += 1
				parser.state = .default
				i += 2
			}
			pending_token.data << runes[i]
			parser.pending_token = pending_token
			continue
		}
		if i + 1 < runes.len && runes[i] == `/` && runes[i + 1] == `*` {
			parser.tokens << Token{
				t_type: .comment_start
				data: [runes[i], runes[i + 1]]
				start: i
			}
			parser.state = .in_block_comment
			i += 2
			continue
		}
		i += 1
	}
	parser.line_info << LineInfo{
		start_token_index: start_token_index
		token_count:       token_count
	}
}

pub fn (mut parser Parser) parse_line_2(line string) {
	mut start_token_index := parser.tokens.len
	mut token_count       := 0
	runes                 := line.runes()

	mut i := 0
	for i < runes.len {
		mut token_start := i
		mut token_type  := TokenType.other
		mut token_data  := []rune{}

		if parser.state == .in_block_comment {
			if i + 1 < runes.len && runes[i] == `*` && runes[i + 1] == `/` {
				if token_data.len > 0 {
					parser.tokens << Token{
						t_type: .comment
						data: token_data
						start: token_start - token_data.len
					}
					token_count += 1
				}

				parser.state = .default
				parser.tokens << Token{
					t_type: .comment_end
					data: "*/".runes()
					start: token_start
				}
				token_count += 1
				i += 2
			} else {
				token_data << runes[i]
				i += 1
			}
		} else {
			match runes[i] {
				`/` {
					if i + 1 < runes.len && runes[i + 1] == `*` {
						token_type = .comment_start
						token_data = "/*".runes()
						parser.state = .in_block_comment
						i += 2
					} else if i + 1 < runes.len && runes[i + 1] == `/` {
						token_type = .comment
						token_data = runes[i..].clone()
						i = runes.len // consume remainder of current line
					} else {
						token_type = .operator
						token_data << runes[i]
						i += 1
					}
				}
				` `, `\t` {
					// whitespace
					token_type = .whitespace
					token_data << runes[i]
					i += 1
					for i < runes.len && (runes[i] == " ".runes()[0] || runes[i] == `\t`) {
						token_data << runes[i]
						i += 1
					}
				}
				`{` {
					token_type = .block_start
					token_data << runes[i]
					i += 1
				}
				`}` {
					token_type = .block_end
					token_data << runes[i]
					i += 1
				}
				`a` ... `z`, `A` ... `Z`, `_` {
					token_type = .identifier
					token_data << runes[i]
					i += 1
					for i < runes.len && (match runes[i] { `a`...`z`, `A`...`Z`, `_`, `0`...`9` { true } else { false } }) {
						token_data << runes[i]
						i += 1
					}
					identifier := token_data.str()
					if identifier in ["fn", "return", "if", "else", "for", "struct"] {
						token_type = .keyword
					}
				}
				`0`...`9` {
					token_type = .number
					token_data << runes[i]
					i += 1
					for i < runes.len && (match runes[i] { `0` ... `9` { true } else { false } }) {
						token_data << runes[i]
						i++
					}

				}
				else {
					token_type = .other
					token_data << runes[i]
					i += 1
				}
			}
		}

		// create and add the token
		if token_data.len > 0 {
			token := Token{
				t_type: token_type
				data:   token_data
				start:  token_start
			}
			parser.tokens << token
			token_count += 1
		}

		if parser.state == .in_block_comment && token_type == .comment_end {
			// reset state after end of block comment
			parser.state = .default
		}
	}

	parser.line_info << LineInfo{
		start_token_index: start_token_index
		token_count:       token_count
	}
}

