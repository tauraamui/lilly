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

struct ChordAction {
	count    int // effective repeat count (pre_count * post_count, minimum 1)
	operator ?u8 // none = pure motion, `d` = delete, etc.
	motion   string
}

enum ChordState {
	empty            // nothing accumulated yet
	pre_count        // accumulating digits before operator/motion
	have_operator    // have operator, expecting post-count or motion
	post_count       // accumulating digits after operator
	motion_prefix    // got a multi-char motion prefix like 'g'
	op_motion_prefix // got operator + 'g', expecting second char
}

struct Chord {
mut:
	buf        []u8 // raw keystroke for label/display
	pre_count  int
	post_count int
	operator   ?u8
	state      ChordState = .empty
}

fn (mut c Chord) feed(key string) ?ChordAction {
	c.buf << key.bytes()

	ch := key[0]
	match c.state {
		.empty, .pre_count {
			if c.is_count_digit(ch, c.pre_count) {
				c.pre_count = c.pre_count * 10 + int(ch - `0`)
				c.state = .pre_count
				return none
			}
			if c.is_operator(ch) {
				c.operator = ch
				c.state = .have_operator
				return none
			}
			if ch == `g` {
				c.state = .motion_prefix
				return none
			}
			if motion := c.single_char_motion(ch) {
				defer { c.reset() }
				return ChordAction{
					count:    c.effective_count()
					operator: none
					motion:   motion
				}
			}
			// unrecognised key, abort current chord
			c.reset()
			return none
		}
		.have_operator, .post_count {
			if c.is_count_digit(ch, c.post_count) {
				c.post_count = c.post_count * 10 + int(ch - `0`)
				c.state = .post_count
				return none
			}
			// operator doubled = linewise (e.g dd)
			if op := c.operator {
				if ch == op {
					defer { c.reset() }
					return ChordAction{
						count:    c.effective_count()
						operator: op
						motion:   'line'
					}
				}
			}
			if ch == `g` {
				c.state = .op_motion_prefix
				return none
			}
			if motion := c.single_char_motion(ch) {
				defer { c.reset() }
				return ChordAction{
					count:    c.effective_count()
					operator: c.operator
					motion:   motion
				}
			}
			c.reset()
			return none
		}
		.motion_prefix {
			defer { c.reset() }
			if ch == `e` {
				return ChordAction{
					count:    c.effective_count()
					operator: none
					motion:   'ge'
				}
			}
			if ch == `g` {
				return ChordAction{
					count:    c.effective_count()
					operator: none
					motion:   'gg'
				}
			}
			// unrecognised g-prefix combo
			return none
		}
		.op_motion_prefix {
			defer { c.reset() }
			if ch == `e` {
				return ChordAction{
					count:    c.effective_count()
					operator: c.operator
					motion:   'ge'
				}
			}
			return none
		}
	}
}

fn (c Chord) display() string {
	return if c.buf.len == 0 { '' } else { c.buf.bytestr() }
}

fn (mut c Chord) reset() {
	c.buf.clear()
	c.pre_count = 0
	c.post_count = 0
	c.operator = none
	c.state = .empty
}

// 0 is only a digit when count already being accumulated
fn (c Chord) is_count_digit(ch u8, current_count int) bool {
	return (ch >= `1` && ch <= `9`) || (ch == `0` && current_count > 0)
}

fn (c Chord) is_operator(ch u8) bool {
	return ch in [`d`, `c`, `y`]
}

fn (c Chord) single_char_motion(ch u8) ?string {
	return match ch {
		`o` { 'o' }
		`w` { 'w' }
		`W` { 'W' }
		`e` { 'e' }
		`b` { 'b' }
		`h` { 'h' }
		`j` { 'j' }
		`k` { 'k' }
		`l` { 'l' }
		`$` { r'$' }
		`0` { '0' }
		`I` { 'I' }
		`A` { 'A' }
		`{` { '{' }
		`}` { '}' }
		`x` { 'x' }
		`v` { 'v' }
		`V` { 'V' }
		`p` { 'p' }
		`P` { 'P' }
		`G` { 'G' }
		`u` { 'u' }
		else { none }
	}
}

fn (c Chord) effective_count() int {
	pre := if c.pre_count == 0 { 1 } else { c.pre_count }
	post := if c.post_count == 0 { 1 } else { c.post_count }
	return pre * post
}
