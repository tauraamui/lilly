// Copyright 2025 The Lilly Edtior contributors
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

module syntax

enum State {
	default
	in_comment
	in_block_comment
	in_double_quote
	in_single_quote
}

pub enum TokenType {
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
	keyword
	literal
	builtin
	other
}

pub struct Token {
	t_type TokenType
mut:
	start int
	end   int
}

pub fn (t Token) start() int {
	return t.start
}

pub fn (t Token) end() int {
	return t.end
}

pub fn (t Token) t_type() TokenType {
	return t.t_type
}

struct LineInfo {
	start_token_index int
	token_count       int
}

pub struct Parser {
	l_syntax []Syntax
mut:
	state         State
	pending_token ?Token
	tokens        []Token
	line_info     []LineInfo
}

pub fn Parser.new(syn []Syntax) Parser {
	return Parser{
		l_syntax: syn
	}
}

pub fn (mut parser Parser) reset() {
	parser.state = .default
	parser.pending_token = none
	parser.tokens.clear()
	parser.line_info.clear()
}

pub fn (parser Parser) get_line_tokens(line_num int) []Token {
	if line_num < 0 || line_num >= parser.line_info.len {
		return []Token{}
	}
	line_info := parser.line_info[line_num]
	start_index := line_info.start_token_index
	end_index := start_index + line_info.token_count
	return parser.tokens[start_index..end_index]
}

pub fn (mut parser Parser) parse_lines(lines []string) {
	for i, line in lines {
		parser.parse_line(i, line)
	}
}

fn resolve_char_type(c_char rune) TokenType {
	// Default classification
	return match c_char {
		` `, `\t` { .whitespace }
		`a`...`z`, `A`...`Z` { .identifier }
		`0`...`9` { .number }
		`"`, `'` { .string } // quotes should be string tokens
		else { .other }
	}
}

fn for_each_char(index int,
	l_char rune, c_char rune,
	mut rune_count &int,
	mut token_count &int,
	mut tokens []Token,
	parser_state State) TokenType {
	current_char_type := resolve_char_type(c_char)
	if l_char != rune(0) {
		last_char_type := resolve_char_type(l_char)

		mut token_type := last_char_type
		if last_char_type != .whitespace {
			token_type = match parser_state {
				.in_comment { TokenType.comment }
				.in_block_comment { TokenType.comment }
				.in_double_quote { TokenType.string }
				.in_single_quote { TokenType.string }
				.default { last_char_type }
			}
		}

		transition_occurred := last_char_type != current_char_type
		if transition_occurred {
			token := Token{
				t_type: token_type
				start:  index - rune_count
				end:    index
			}
			tokens << token
			token_count += 1
			rune_count = 0
		}
	}

	rune_count += 1
	return current_char_type
}

pub fn (mut parser Parser) parse_line(index int, line string) []Token {
	mut start_token_index := parser.tokens.len
	mut token_count := 0
	mut rune_count := 0
	runes := line.runes()
	if parser.state == .in_comment {
		parser.state = .default
	}
	// single line comments terminate at the end of the line

	mut token_type := TokenType.other
	for i, c_char in runes {
		mut l_char := rune(0)
		if i > 0 {
			l_char = runes[i - 1]
		}

		// store the previous state before updating
		previous_state := parser.state

		parser.state = match parser.state {
			.default {
				match true {
					l_char == `/` && c_char == `/` { .in_comment }
					l_char == `/` && c_char == `*` { .in_block_comment }
					c_char == `"` { .in_double_quote }
					c_char == `'` { .in_single_quote }
					else { State.default }
				}
			}
			.in_double_quote {
				if c_char == `"` { State.default } else { State.in_double_quote }
			}
			.in_single_quote {
				if c_char == `'` { State.default } else { State.in_single_quote }
			}
			.in_block_comment {
				match true {
					l_char == `*` && c_char == `/` { State.default }
					else { State.in_block_comment }
				}
			}
			else {
				parser.state
			}
		}

		// use previous_state for classifying the previous character
		token_type = for_each_char(i, l_char, c_char, mut &rune_count, mut &token_count, mut
			parser.tokens, previous_state)
	}

	token_type = match parser.state {
		.in_comment { TokenType.comment }
		.in_block_comment { TokenType.comment }
		.in_double_quote { TokenType.string }
		.in_single_quote { TokenType.string }
		else { token_type }
	}

	if rune_count > 0 {
		token := Token{
			t_type: token_type
			start:  runes.len - rune_count
			end:    runes.len
		}
		parser.tokens << token
		token_count += 1
	}

	line_info := LineInfo{
		start_token_index: start_token_index
		token_count:       token_count
	}
	parser.line_info << line_info
	return parser.get_line_tokens(index)
}
