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
	start  int
	end    int
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

pub fn (mut parser Parser) parse_lines(lines []string) {
	for i, line in lines { parser.parse_line(i, line) }
}

fn resolve_char_type(c_char rune) TokenType {
	return match c_char {
		` `, `\t` { .whitespace }
		`a` ... `z`, `A` ... `Z` { .identifier }
		`0` ... `9` { .number }
		else { .other }
	}
}

fn for_each_char(
	index int, l_char rune, c_char rune, mut rune_count &int, mut token_count &int, mut tokens []Token, within_line_comment bool
) TokenType {
	last_char_type := resolve_char_type(l_char)
	current_char_type := resolve_char_type(c_char)

	transition_occurred := last_char_type != current_char_type
	if transition_occurred {
		token := Token{
			t_type: if within_line_comment { .comment } else { last_char_type }
			start: index - rune_count
			end: index
		}
		tokens << token
		token_count += 1
		rune_count = 0
	}

	rune_count += 1
	return current_char_type
}

pub fn (mut parser Parser) parse_line(index int, line string) []Token {
	mut start_token_index   := parser.tokens.len
	mut token_count         := 0
	mut rune_count          := 0
	runes                   := line.runes()
	mut within_line_comment := false

	mut token_type := TokenType.other
	for i, c_char in runes {
		mut l_char := c_char
		if i > 0 {
			l_char = runes[i - 1]
			if within_line_comment == false {
				within_line_comment = l_char == `/` && c_char == `/`
			}
		}
		token_type = for_each_char(i, l_char, c_char, mut &rune_count, mut &token_count, mut parser.tokens, within_line_comment)
	}

	if rune_count > 0 {
		token := Token{
			t_type: if within_line_comment { .comment } else { token_type }
			start: runes.len - rune_count
			end: runes.len
		}
		parser.tokens << token
		token_count += 1
	}

	line_info := LineInfo{
		start_token_index: start_token_index
		token_count: token_count
	}
	parser.line_info << line_info
	return parser.get_line_tokens(index)
}

