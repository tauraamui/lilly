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

// State identifies the stack of grammar contexts open at the start of a line,
// so a line can be lexed without lexing the lines above it. 0 is a line that
// starts outside every string and comment.
//
// Stacks one or two deep, which is nearly all of them (inside a block comment
// is `main > block_comment`), are encoded directly. Deeper ones are interned
// by the parser that saw them, so states from different parsers can't be
// compared.
pub type State = u16

// deep_state_base is the first interned state: below it are stacks of one
// context (0..255) and of main plus one context (256..511)
const deep_state_base = 512
const max_deep_states = 65535 - deep_state_base

// max_stack_depth bounds how deeply contexts nest, e.g. Rust's nested block
// comments. Pushes past it are ignored.
const max_stack_depth = 32

// max_stalls bounds how many zero-length matches can change the stack at one
// position, so a grammar whose lookaheads push and pop in a cycle can't hang.
const max_stalls = 8

// TokenType is the coarse kind of a token, kept for the original editor's
// keyword-list colouring. New code uses Token.scope.
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
pub:
	scope Scope
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

pub fn (t Token) scope() Scope {
	return t.scope
}

pub fn (t Token) t_type() TokenType {
	return match t.scope {
		.comment, .comment_doc { .comment }
		.string, .string_escape { .string }
		.number { .number }
		.keyword, .keyword_control, .keyword_directive, .keyword_operator { .keyword }
		.literal { .literal }
		.builtin { .builtin }
		.operator { .operator }
		else { .other }
	}
}

// Op is what a matched rule does to the context stack. pop_through pops
// like pop, but in the tree the context's node runs on through the bracket
// the rule matched, closing when it does, e.g. a function from `fn` through
// its body's braces, while the lexer is back in the context around it.
// escape leaves an embedded grammar: it pops every context down to and
// including the target, the root of the embedded grammar's contexts.
enum Op as u8 {
	none
	push
	pop
	set
	pop_through
	escape
}

// Match is a generated context's answer at one position. When no rule
// matches, end is -1 and next is the first later position a rule could
// match at, so the runes in between are plain text of the context.
struct Match {
	end    int = -1
	next   int
	scope  Scope
	op     Op
	target u8
}

// LangInfo is the per-context data the driver needs from a generated lexer
struct LangInfo {
	names       []string
	scopes      []Scope
	pops_at_eol []bool
}

const plain_info = LangInfo{
	names:       ['main']
	scopes:      [Scope.none]
	pops_at_eol: [false]
}

// TreeEvent is a node of the context tree opening or closing, recorded by lex
// when the parser's `record` is set. An open's col is where its first rune
// is; a close's col is just past its last rune, so a node covers
// [open col, close col).
struct TreeEvent {
	col     int
	open    bool
	bracket bool
	// ties marks a bracket opened by a rule popping through it: the context
	// inside which it opens closes when it does
	ties bool
	// id is the context opened or closed, or for a bracket its index in
	// `([{` or `)]}`
	id u8
}

const bracket_opens = [`(`, `[`, `{`]
const bracket_closes = [`)`, `]`, `}`]

pub struct Parser {
mut:
	lang   Lang
	info   LangInfo = plain_info
	stack  []u8     = [u8(0)]
	tokens []Token
	// deep_states and deep_ids intern stacks too deep to encode in a State
	deep_states [][]u8
	deep_ids    map[string]State
	// code says, for each context, whether brackets in it count, which they
	// don't in strings and comments
	code []bool = [true]
	// record makes lex fill events with the line's opens and closes
	record bool
	events []TreeEvent
}

// set_syntax switches the parser to the generated lexer for `syn`. States
// from before the switch mean nothing afterwards.
pub fn (mut parser Parser) set_syntax(syn Syntax) {
	parser.lang = syn.lang
	parser.info = lang_info(syn.lang)
	parser.deep_states = [][]u8{}
	parser.deep_ids = map[string]State{}
	parser.code = parser.info.scopes.map(it !in [.comment, .comment_doc, .string, .string_escape])
	parser.reset()
}

pub fn (mut parser Parser) reset() {
	parser.stack.clear()
	parser.stack << 0
	parser.tokens.clear()
}

pub fn (parser &Parser) current_state() State {
	stack := parser.stack
	if stack.len == 1 {
		return State(stack[0])
	}
	if stack.len == 2 && stack[0] == 0 {
		return State(256 + int(stack[1]))
	}
	// lex interns the stack before a line ends, and set_state only loads
	// interned stacks, so a deep stack is always found here
	return parser.deep_ids[stack.bytestr()] or { 0 }
}

pub fn (mut parser Parser) set_state(s State) {
	parser.stack.clear()
	if s < 256 {
		parser.stack << u8(s)
		return
	}
	if s < deep_state_base {
		parser.stack << 0
		parser.stack << u8(s - 256)
		return
	}
	if int(s) - deep_state_base < parser.deep_states.len {
		parser.stack << parser.deep_states[int(s) - deep_state_base]
		return
	}
	parser.stack << 0
}

// state_name describes a state as its stack of context names, e.g.
// `main > string > interpolation`. Unlike the State itself, the name can be
// compared between parsers.
pub fn (parser Parser) state_name(s State) string {
	mut p := Parser{
		lang:        parser.lang
		info:        parser.info
		deep_states: parser.deep_states
	}
	p.set_state(s)
	return p.stack.map(parser.info.names[it]).join(' > ')
}

// intern_state makes sure the current stack has a State, for stacks too deep
// to encode directly
fn (mut parser Parser) intern_state() {
	stack := parser.stack
	if stack.len == 1 || (stack.len == 2 && stack[0] == 0) {
		return
	}
	key := stack.bytestr()
	if key in parser.deep_ids {
		return
	}
	if parser.deep_states.len >= max_deep_states {
		// out of ids: keep just the innermost context, which colours the
		// next line right until it pops
		top := stack.last()
		parser.stack.clear()
		parser.stack << 0
		if top != 0 {
			parser.stack << top
		}
		return
	}
	parser.deep_ids[key] = State(deep_state_base + parser.deep_states.len)
	parser.deep_states << stack.clone()
}

// advance_state_runes moves the parser past a line without producing tokens,
// for lines whose state matters but which aren't drawn
pub fn (mut parser Parser) advance_state_runes(runes []rune) {
	parser.lex(runes, false)
}

// parse_line lexes the next line, giving its tokens and leaving the parser
// in the state the line after it starts in
pub fn (mut parser Parser) parse_line(line string) []Token {
	return parser.parse_line_runes(line.runes())
}

// parse_line_runes is parse_line for a line already decoded into runes
pub fn (mut parser Parser) parse_line_runes(runes []rune) []Token {
	start := parser.tokens.len
	parser.lex(runes, true)
	return parser.tokens[start..]
}

// lex runs one line through the generated lexer, appending its tokens when
// `emit` is set. parse_line and advance_state_runes both come through here,
// so the per-line states the editor caches always agree with the tokens drawn.
@[direct_array_access]
fn (mut parser Parser) lex(runes []rune, emit bool) {
	if parser.stack.len == 0 {
		parser.stack << 0
	}
	line_start := parser.tokens.len
	if parser.record {
		parser.events.clear()
	}
	mut i := 0
	mut stalls := 0
	for i < runes.len {
		m := lang_step(parser.lang, parser.stack.last(), runes, i, emit)
		if m.end < 0 || (m.end == i && (m.op == .none || stalls >= max_stalls)) {
			// plain text of the current context, up to where a rule could
			// next match
			j := if m.end < 0 && m.next > i { m.next } else { i + 1 }
			if emit {
				parser.emit(line_start, parser.info.scopes[parser.stack.last()], i, j)
			}
			if parser.record && parser.code[parser.stack.last()] {
				parser.record_brackets(runes, i, j)
			}
			i = j
			stalls = 0
			continue
		}
		if emit {
			parser.emit(line_start, m.scope, i, m.end)
		}
		if parser.record {
			parser.record_match(runes, i, m)
		}
		stalls = if m.end == i { stalls + 1 } else { 0 }
		i = m.end
		match m.op {
			// TODO(tauraamui) [14/10/2026]: look into defining exception to highlighting 'none' when used as
			// case definition
			.none {}
			.push {
				if parser.stack.len < max_stack_depth {
					parser.stack << m.target
				}
			}
			.pop, .pop_through {
				if parser.stack.len > 1 {
					parser.stack.delete_last()
				}
			}
			.set {
				parser.stack[parser.stack.len - 1] = m.target
			}
			.escape {
				for parser.stack.len > 1 {
					top := parser.stack.pop()
					if top == m.target {
						break
					}
				}
			}
		}
	}
	for parser.stack.len > 1 && parser.info.pops_at_eol[parser.stack.last()] {
		if parser.record {
			parser.events << TreeEvent{
				col: runes.len
				id:  parser.stack.last()
			}
		}
		parser.stack.delete_last()
	}
	parser.intern_state()
}

// emit appends a token, folding it into the one before when they touch and
// share a scope, so a string's quotes and contents draw as one token
@[direct_array_access]
fn (mut parser Parser) emit(line_start int, scope Scope, start int, end int) {
	if end <= start {
		return
	}
	last := parser.tokens.len - 1
	if last >= line_start && parser.tokens[last].scope == scope && parser.tokens[last].end == start {
		parser.tokens[last].end = end
		return
	}
	parser.tokens << Token{
		scope: scope
		start: start
		end:   end
	}
}

// record_match records what a rule matched at `start` opens or closes,
// mirroring the stack change lex is about to make. Brackets a rule matched as
// punctuation or operators count, but not ones inside a token like an
// attribute. A context pushed by a bracket, like a parameter list, is a
// bracket node too, inside the context's node, so bracket matching works on
// it as it would without the context. That goes for a code context pushed
// from a string too, like the `${` of an interpolation.
fn (mut parser Parser) record_match(runes []rune, start int, m Match) {
	top := parser.stack.last()
	brackets := parser.code[top] && m.scope in [.none, .punctuation, .operator]
	match m.op {
		.none {
			if brackets {
				parser.record_brackets(runes, start, m.end)
			}
		}
		.push {
			if parser.stack.len < max_stack_depth {
				parser.events << TreeEvent{
					col:  start
					open: true
					id:   m.target
				}
				// a string's interpolation, pushed by `${`, opens code inside
				// the string, so its brace is a bracket as it would be in code
				pushes_code := parser.code[m.target]
					&& m.scope in [.none, .punctuation, .operator]
				if brackets || pushes_code {
					parser.record_brackets(runes, start, m.end)
				}
			}
		}
		.pop {
			if parser.stack.len > 1 {
				// a bracket closing it is closed with it
				parser.events << TreeEvent{
					col: m.end
					id:  top
				}
			}
		}
		.pop_through {
			if parser.stack.len > 1 {
				parser.record_pop_through(runes, start, m.end, top)
			}
		}
		.escape {
			// closing the embedded grammar's root closes whatever it left
			// open inside it
			if parser.stack.len > 1 {
				parser.events << TreeEvent{
					col: m.end
					id:  m.target
				}
			}
		}
		.set {
			// as with pop, the root is no node to close, nor what replaces it
			if parser.stack.len > 1 {
				parser.events << TreeEvent{
					col: m.end
					id:  top
				}
				parser.events << TreeEvent{
					col:  m.end
					open: true
					id:   m.target
				}
			}
		}
	}
}

// record_pop_through records context `top` popping through the first bracket
// opening among runes `start` to `end`, or just popping without one
@[direct_array_access]
fn (mut parser Parser) record_pop_through(runes []rune, start int, end int, top u8) {
	for k in start .. end {
		opens := bracket_opens.index(runes[k])
		if opens >= 0 {
			parser.events << TreeEvent{
				col:     k
				open:    true
				bracket: true
				ties:    true
				id:      u8(opens)
			}
			return
		}
	}
	parser.events << TreeEvent{
		col: end
		id:  top
	}
}

// record_brackets records the brackets among runes `start` to `end`
@[direct_array_access]
fn (mut parser Parser) record_brackets(runes []rune, start int, end int) {
	for k in start .. end {
		r := runes[k]
		opens := bracket_opens.index(r)
		if opens >= 0 {
			parser.events << TreeEvent{
				col:     k
				open:    true
				bracket: true
				id:      u8(opens)
			}
			continue
		}
		closes := bracket_closes.index(r)
		if closes >= 0 {
			parser.events << TreeEvent{
				col:     k + 1
				bracket: true
				id:      u8(closes)
			}
		}
	}
}
