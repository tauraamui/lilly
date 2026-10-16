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

import math

struct ChordAction {
	count    int // effective repeat count (pre_count * post_count, minimum 1)
	operator ?u8 // none = pure motion, `d` = delete, etc.
	motion   string
	// counted is set when a count was typed, which `%` needs to tell `1%`,
	// the first line, from a bare `%`
	counted bool
}

enum ChordState {
	empty         // nothing accumulated yet
	pre_count     // accumulating digits before operator/motion
	have_operator // have operator, expecting post-count or motion
	post_count    // accumulating digits after operator
	motion_prefix // got a multi-char motion prefix like 'g'
	z_motion_prefix
	op_motion_prefix // got operator + 'g', expecting second char
	text_object      // got `i` or `a` after an operator or in visual mode, expecting the object
}

struct Chord {
mut:
	buf        []u8 // raw keystroke for label/display
	pre_count  int
	post_count int
	operator   ?u8
	object     u8 // `i` or `a`, while a text object is pending
	state      ChordState = .empty
}

fn (mut c Chord) feed(key string) ?ChordAction {
	return c.feed_internal(key, false)
}

// feed_visual is like feed, but treats operators as standalone actions
// in visual mode the selection supplies the range, so `d`/`c`/`y` must
// fire immediately rather than wait for a motion.
fn (mut c Chord) feed_visual(key string) ?ChordAction {
	return c.feed_internal(key, true)
}

fn (mut c Chord) feed_internal(key string, in_visual bool) ?ChordAction {
	c.buf << key.bytes()

	ch := key[0]
	match c.state {
		.empty, .pre_count {
			if c.is_count_digit(ch, c.pre_count) {
				c.pre_count = grow_count(c.pre_count, ch)
				c.state = .pre_count
				return none
			}
			if in_visual && ch in [`i`, `a`] {
				c.object = ch
				c.state = .text_object
				return none
			}
			if c.is_operator(ch) {
				if in_visual {
					defer { c.reset() }
					return ChordAction{
						count:    c.effective_count()
						operator: ch
						motion:   ''
					}
				}
				c.operator = ch
				c.state = .have_operator
				return none
			}
			if ch == `g` {
				c.state = .motion_prefix
				return none
			}
			if ch == `z` {
				c.state = .z_motion_prefix
				return none
			}
			if motion := c.single_char_motion(ch) {
				defer { c.reset() }
				return ChordAction{
					count:    c.effective_count()
					operator: none
					motion:   motion
					counted:  c.pre_count > 0
				}
			}
			// unrecognised key, abort current chord
			c.reset()
			return none
		}
		.have_operator, .post_count {
			if c.is_count_digit(ch, c.post_count) {
				c.post_count = grow_count(c.post_count, ch)
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
			if ch in [`i`, `a`] {
				c.object = ch
				c.state = .text_object
				return none
			}
			if motion := c.single_char_motion(ch) {
				defer { c.reset() }
				return ChordAction{
					count:    c.effective_count()
					operator: c.operator
					motion:   motion
					counted:  c.pre_count > 0 || c.post_count > 0
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
		.z_motion_prefix {
			defer { c.reset() }
			// zz, and the fold commands
			if ch in [`z`, `o`, `O`, `c`, `C`, `a`, `A`, `R`, `M`, `j`, `k`] {
				return ChordAction{
					count:    c.effective_count()
					operator: none
					motion:   'z${rune(ch)}'
				}
			}
			return none
		}
		.text_object {
			defer { c.reset() }
			object := c.text_object(ch)?
			return ChordAction{
				count:    c.effective_count()
				operator: c.operator
				motion:   '${rune(c.object)}${rune(object)}'
			}
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
	c.object = 0
	c.state = .empty
}

// 0 is only a digit when count already being accumulated
fn (c Chord) is_count_digit(ch u8, current_count int) bool {
	return (ch >= `1` && ch <= `9`) || (ch == `0` && current_count > 0)
}

fn (c Chord) is_operator(ch u8) bool {
	return ch in [`d`, `c`, `y`]
}

// pending_operator reports whether an operator is waiting for its motion or
// text object, so the next key is the chord's, not a mode switch
fn (c Chord) pending_operator() bool {
	return c.state in [.have_operator, .post_count, .op_motion_prefix, .text_object]
}

// text_object gives the delimiter a text object is named by, the opening one
// for a bracket, whichever of the pair or Vim's `b` and `B` names it
fn (c Chord) text_object(ch u8) ?u8 {
	return match ch {
		`(`, `)`, `b` { `(` }
		`[`, `]` { `[` }
		`{`, `}`, `B` { `{` }
		`"`, `'`, `\`` { ch }
		else { none }
	}
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
		// `v` { 'v' }
		// `V` { 'V' }
		`p` { 'p' }
		`P` { 'P' }
		`G` { 'G' }
		`u` { 'u' }
		`^` { '^' }
		`%` { '%' }
		else { none }
	}
}

fn (c Chord) effective_count() int {
	pre := if c.pre_count == 0 { 1 } else { c.pre_count }
	post := if c.post_count == 0 { 1 } else { c.post_count }
	return math.min(pre * post, max_count)
}

// max_count caps a typed count, as Vim does, so a long run of digits can't
// overflow it, and a count times a count can't either
const max_count = 999_999_999

// grow_count appends digit ch to a count being typed
fn grow_count(count int, ch u8) int {
	return math.min(count * 10 + int(ch - `0`), max_count)
}
