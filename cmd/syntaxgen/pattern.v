// Copyright 2026 The Lilly Edtior contributors
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

// Patterns look like regular expressions but match the way a PEG does:
// repeats take as much as they can and never give any back, and `a|b` takes
// the first alternative that matches. That is what lets them compile to
// straight-line code with no backtracking engine. The syntax:
//
//   x          a literal rune; `\` escapes any punctuation
//   .          any rune
//   [a-z_]     a class; [^...] negates it
//   \w \d \s \h  word, digit, space-or-tab and hex-digit classes, and
//              \W \D \S \H their negations
//   \t         a tab
//   (...)  (?:...)  a group
//   a|b        ordered choice
//   * + ? {n} {n,} {n,m}  repeats
//   (?=...) (?!...)  lookahead, which consumes nothing
//   ^ $        start and end of the line

enum Kind {
	seq
	alt
	rep
	class
	look
	bol
	eol
}

struct Range {
	lo rune
	hi rune
}

struct Node {
	kind Kind
	kids []Node
	// ranges are a class's runes; a negated class with none matches any rune
	ranges  []Range
	negated bool
	min     int
	// max is -1 for no limit
	max int
}

fn (n Node) is_any() bool {
	return n.kind == .class && n.negated && n.ranges.len == 0
}

struct PatternParser {
	src []rune
mut:
	pos int
}

fn parse_pattern(src string) !Node {
	mut pp := PatternParser{
		src: src.runes()
	}
	node := pp.alt()!
	if pp.pos < pp.src.len {
		return error('pattern "${src}": unexpected "${pp.src[pp.pos]}" at ${pp.pos}')
	}
	return node
}

fn (pp PatternParser) peek() rune {
	return if pp.pos < pp.src.len { pp.src[pp.pos] } else { 0 }
}

fn (mut pp PatternParser) alt() !Node {
	mut alts := [pp.seq()!]
	for pp.peek() == `|` {
		pp.pos++
		alts << pp.seq()!
	}
	if alts.len == 1 {
		return alts[0]
	}
	return Node{
		kind: .alt
		kids: alts
	}
}

fn (mut pp PatternParser) seq() !Node {
	mut items := []Node{}
	for pp.pos < pp.src.len && pp.peek() != `|` && pp.peek() != `)` {
		atom := pp.atom()!
		items << pp.quantified(atom)!
	}
	if items.len == 1 {
		return items[0]
	}
	return Node{
		kind: .seq
		kids: items
	}
}

fn (mut pp PatternParser) atom() !Node {
	c := pp.src[pp.pos]
	pp.pos++
	match c {
		`(` {
			mut kind := Kind.seq
			mut negated := false
			if pp.peek() == `?` {
				pp.pos++
				match pp.peek() {
					`:` {}
					`=` {
						kind = .look
					}
					`!` {
						kind = .look
						negated = true
					}
					else {
						return error('unknown group "(?${pp.peek()}"')
					}
				}
				pp.pos++
			}
			inner := pp.alt()!
			if pp.peek() != `)` {
				return error('missing ")"')
			}
			pp.pos++
			if kind == .look {
				return Node{
					kind:    .look
					kids:    [inner]
					negated: negated
				}
			}
			return inner
		}
		`[` {
			return pp.class()!
		}
		`.` {
			return Node{
				kind:    .class
				negated: true
			}
		}
		`^` {
			return Node{
				kind: .bol
			}
		}
		`$` {
			return Node{
				kind: .eol
			}
		}
		`\\` {
			if pp.pos >= pp.src.len {
				return error('pattern ends with "\\"')
			}
			e := pp.src[pp.pos]
			pp.pos++
			ranges, negated := escape_class(e)!
			return Node{
				kind:    .class
				ranges:  ranges
				negated: negated
			}
		}
		`*`, `+`, `?`, `{` {
			return error('"${c}" has nothing to repeat')
		}
		else {
			return literal(c)
		}
	}
}

fn (mut pp PatternParser) quantified(atom Node) !Node {
	mut min, mut max := 0, 0
	match pp.peek() {
		`*` {
			min, max = 0, -1
		}
		`+` {
			min, max = 1, -1
		}
		`?` {
			min, max = 0, 1
		}
		`{` {
			pp.pos++
			min = pp.number()!
			max = min
			if pp.peek() == `,` {
				pp.pos++
				max = if pp.peek() == `}` { -1 } else { pp.number()! }
			}
			if pp.peek() != `}` {
				return error('missing "}"')
			}
			if max >= 0 && max < min {
				return error('repeat {${min},${max}} has max below min')
			}
		}
		else {
			return atom
		}
	}
	pp.pos++
	if atom.kind in [.look, .bol, .eol] {
		return error("a lookahead or anchor can't repeat")
	}
	return Node{
		kind: .rep
		kids: [atom]
		min:  min
		max:  max
	}
}

fn (mut pp PatternParser) number() !int {
	start := pp.pos
	for pp.peek() >= `0` && pp.peek() <= `9` {
		pp.pos++
	}
	if pp.pos == start {
		return error('expected a number in {}')
	}
	return pp.src[start..pp.pos].string().int()
}

fn (mut pp PatternParser) class() !Node {
	mut negated := false
	if pp.peek() == `^` {
		negated = true
		pp.pos++
	}
	mut ranges := []Range{}
	for {
		if pp.pos >= pp.src.len {
			return error('missing "]"')
		}
		mut c := pp.src[pp.pos]
		pp.pos++
		if c == `]` {
			break
		}
		if c == `\\` {
			if pp.pos >= pp.src.len {
				return error('pattern ends with "\\"')
			}
			e := pp.src[pp.pos]
			pp.pos++
			escaped, escaped_negated := escape_class(e)!
			if escaped_negated {
				return error('"\\${e}" can\'t go inside []')
			}
			if escaped.len != 1 || escaped[0].lo != escaped[0].hi {
				ranges << escaped
				continue
			}
			c = escaped[0].lo
		}
		if pp.peek() == `-` && pp.pos + 1 < pp.src.len && pp.src[pp.pos + 1] != `]` {
			pp.pos++
			mut hi := pp.src[pp.pos]
			pp.pos++
			if hi == `\\` && pp.pos < pp.src.len {
				hi = pp.src[pp.pos]
				pp.pos++
				if is_alnum(hi) {
					return error('"\\${hi}" can\'t end a range')
				}
			}
			if hi < c {
				return error('range ${c}-${hi} is backwards')
			}
			ranges << Range{c, hi}
			continue
		}
		ranges << Range{c, c}
	}
	return Node{
		kind:    .class
		ranges:  ranges
		negated: negated
	}
}

// escape_class returns the runes `\e` stands for, and whether they are
// negated. Escaping punctuation makes it literal; a letter or digit that isn't
// a known escape is an error rather than itself, so `\n` or `\b` can't
// silently match `n` or `b`.
fn escape_class(e rune) !([]Range, bool) {
	word := [Range{`a`, `z`}, Range{`A`, `Z`}, Range{`0`, `9`}, Range{`_`, `_`}]
	digit := [Range{`0`, `9`}]
	space := [Range{` `, ` `}, Range{`\t`, `\t`}]
	hex := [Range{`0`, `9`}, Range{`a`, `f`}, Range{`A`, `F`}]
	return match e {
		`w` { word, false }
		`W` { word, true }
		`d` { digit, false }
		`D` { digit, true }
		`s` { space, false }
		`S` { space, true }
		`h` { hex, false }
		`H` { hex, true }
		`t` { [Range{`\t`, `\t`}], false }
		else {
			if is_alnum(e) {
				return error('unknown escape "\\${e}"')
			}
			[Range{e, e}], false
		}
	}
}

fn is_alnum(r rune) bool {
	return (r >= `a` && r <= `z`) || (r >= `A` && r <= `Z`) || (r >= `0` && r <= `9`)
}

fn literal(c rune) Node {
	return Node{
		kind:   .class
		ranges: [Range{c, c}]
	}
}

// First is what the first rune a node consumes must be
struct First {
mut:
	classes []Node
	// nullable is set when the node can match without consuming anything
	nullable bool
	// any is set when the first rune can be anything
	any bool
}

fn first_of(n Node) First {
	match n.kind {
		.class {
			if n.is_any() {
				return First{
					any: true
				}
			}
			return First{
				classes: [n]
			}
		}
		.seq {
			mut out := First{}
			for kid in n.kids {
				f := first_of(kid)
				out.classes << f.classes
				out.any = out.any || f.any
				if !f.nullable {
					return out
				}
			}
			out.nullable = true
			return out
		}
		.alt {
			mut out := First{}
			for kid in n.kids {
				f := first_of(kid)
				out.classes << f.classes
				out.any = out.any || f.any
				out.nullable = out.nullable || f.nullable
			}
			return out
		}
		.rep {
			mut f := first_of(n.kids[0])
			f.nullable = f.nullable || n.min == 0
			return f
		}
		.look, .bol, .eol {
			return First{
				nullable: true
			}
		}
	}
}

// starts_at_bol reports whether a pattern can only match at the start of a line
fn starts_at_bol(n Node) bool {
	return n.kind == .bol || (n.kind == .seq && n.kids[0].kind == .bol)
}
