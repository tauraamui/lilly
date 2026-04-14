// Copyright 2026 The Lilly Editor contributors
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

module main

import strconv

type Token = InputToken | WaitToken

struct InputToken {
	label string
	bytes []u8
}

struct WaitToken {
	ms int
}

// parse_input converts an input specification string into a sequence of tokens.
// Literal characters are sent as-is. Special sequences inside angle brackets
// are mapped to their corresponding byte sequences:
//
//   <enter>  -> \r
//   <esc>    -> \x1b
//   <tab>    -> \t
//   <space>  -> ' '
//   <bs>     -> \x7f
//   <up>     -> \x1b[A
//   <down>   -> \x1b[B
//   <right>  -> \x1b[C
//   <left>   -> \x1b[D
//   <wait:N> -> pause N milliseconds
fn parse_input(spec string) []Token {
	mut tokens := []Token{}
	mut i := 0
	runes := spec.runes()

	for i < runes.len {
		if runes[i] == `<` {
			// Find matching closing bracket.
			end := find_closing_bracket(runes, i)
			if end > 0 {
				tag := runes_to_string(runes[i + 1..end])
				token := resolve_tag(tag)
				tokens << token
				i = end + 1
				continue
			}
		}
		// Literal character
		c := runes[i]
		tokens << Token(InputToken{
			label: c.str()
			bytes: c.str().bytes()
		})
		i++
	}
	return tokens
}

fn find_closing_bracket(runes []rune, start int) int {
	for j := start + 1; j < runes.len; j++ {
		if runes[j] == `>` {
			return j
		}
	}
	return -1
}

fn runes_to_string(runes []rune) string {
	mut s := ''
	for r in runes {
		s += r.str()
	}
	return s
}

fn resolve_tag(tag string) Token {
	lower := tag.to_lower()

	// Check for wait:NNN pattern
	if lower.starts_with('wait:') {
		ms_str := lower[5..]
		ms := strconv.atoi(ms_str) or { 500 }
		return Token(WaitToken{ ms: ms })
	}

	bytes, label := match lower {
		'enter', 'return', 'cr' {
			[u8(0x0d)], 'ENTER'
		}
		'esc', 'escape' {
			[u8(0x1b)], 'ESC'
		}
		'tab' {
			[u8(0x09)], 'TAB'
		}
		'space' {
			[u8(0x20)], 'SPACE'
		}
		'bs', 'backspace' {
			[u8(0x7f)], 'BACKSPACE'
		}
		'up' {
			[u8(0x1b), u8(`[`), u8(`A`)], 'UP'
		}
		'down' {
			[u8(0x1b), u8(`[`), u8(`B`)], 'DOWN'
		}
		'right' {
			[u8(0x1b), u8(`[`), u8(`C`)], 'RIGHT'
		}
		'left' {
			[u8(0x1b), u8(`[`), u8(`D`)], 'LEFT'
		}
		'home' {
			[u8(0x1b), u8(`[`), u8(`H`)], 'HOME'
		}
		'end' {
			[u8(0x1b), u8(`[`), u8(`F`)], 'END'
		}
		'pgup', 'pageup' {
			[u8(0x1b), u8(`[`), u8(`5`), u8(`~`)], 'PGUP'
		}
		'pgdn', 'pagedown' {
			[u8(0x1b), u8(`[`), u8(`6`), u8(`~`)], 'PGDN'
		}
		'del', 'delete' {
			[u8(0x1b), u8(`[`), u8(`3`), u8(`~`)], 'DEL'
		}
		'ctrl-c' {
			[u8(0x03)], 'CTRL-C'
		}
		'ctrl-d' {
			[u8(0x04)], 'CTRL-D'
		}
		'ctrl-z' {
			[u8(0x1a)], 'CTRL-Z'
		}
		else {
			// Unknown tag — send the literal characters including brackets.
			tag_str := '<${tag}>'
			tag_str.bytes(), tag_str
		}
	}

	return Token(InputToken{
		label: label
		bytes: bytes
	})
}
