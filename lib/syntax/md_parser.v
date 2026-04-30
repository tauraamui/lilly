module syntax

pub enum MarkdownTokenType {
	none
	header
}

pub struct MarkdownToken {
	t_type MarkdownTokenType
	start  int
	end    int
}

pub struct MarkdownParserState {
mut:
	last_type   TokenType
	last_end    int
	active_type MarkdownTokenType
}

pub fn parse_markdown_line(mut state MarkdownParserState, line string) []MarkdownToken {
	mut tokens := []MarkdownToken{}
	for i, r in line.runes_iterator() {
		char_type := resolve_char_type(r, []rune{})
		if char_type == .whitespace && state.last_type != .whitespace {
			tokens << MarkdownToken{ t_type: .header, start: state.last_end, end: i }
		}
		state.last_type = char_type
		state.last_end = i
	}
	return tokens
}

