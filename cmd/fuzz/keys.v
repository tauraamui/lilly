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

import rand

enum StepKind {
	keys   // send bytes as typed input
	resize // change the terminal size
	probe  // check lilly still redraws, see Runner.probe
}

// Step is one action in a run. Every step waits delay_ms first, so a replay
// sends the same bytes with the same gaps: lilly reads a lone escape
// differently from one with more bytes hard behind it.
struct Step {
	kind     StepKind
	delay_ms int
	bytes    []u8
	cols     u16
	rows     u16
}

// a probe every this many steps, on average, so a hang is caught near the
// keys that caused it rather than only at the end of the run
const probe_every = 150

const normal_keys = 'hjklwbeWBE0$^{}%xXpPuGgIAaioOvVdycrRfFtTnN.~<>=J/?*#:;zZmM'.bytes()

// ctrl+r, u, d, w, v, o, e, y, f, b, n, p, a, x, l, g
const ctrl_keys = [u8(0x12), 0x15, 0x04, 0x17, 0x16, 0x0f, 0x05, 0x19, 0x06, 0x02, 0x0e, 0x10,
	0x01, 0x18, 0x0c, 0x07]

const chords = ['gg', 'ge', 'dd', 'yy', 'cc', 'dw', 'de', 'db', 'cw', 'ce', 'ciw', 'caw', 'diw',
	'daw', 'yiw', 'di(', 'da(', 'di{', 'da{', 'di[', 'ci"', "ci'", 'ci`', 'vi{', 'va(', 'zf', 'za',
	'zo', 'zc', 'zR', 'zM', 'zj', 'zk', '>>', '<<', '==', 'dG', 'dgg', 'd$', 'd0', 'd^', 'y$',
	'c$', '2dd', '10j', '5x', '99G', '3w', 'gJ', '\x17h', '\x17j', '\x17k', '\x17l', '\x17v', '\x17s']

const commands = ['q', 'w', 'vs', 'sp', 'InspectTree', 'inspecttree', '1', '0', '-1', '999999',
	'99999999999999999999', '', ' ', 'w!', 'e', 'set', 'q!']

const special_keys = ['\x1b', '\r', '\t', '\x1b[Z', '\x7f', '\x08', '\x1b[3~', '\x1b[A', '\x1b[B',
	'\x1b[C', '\x1b[D', '\x1b[H', '\x1b[F', '\x1b[1~', '\x1b[4~', '\x1b[5~', '\x1b[6~', '\x1b[2~',
	'\x1bOP', '\x1bOQ', '\x1bOR', '\x1bOS', '\x1b[15~', '\x1b[17~', '\x1b[18~', '\x1b[19~', '\x1b[20~',
	'\x1b[21~', '\x1b[23~', '\x1b[24~', '\x1b[1;5A', '\x1b[1;5B', '\x1b[1;5C', '\x1b[1;5D', '\x1b[1;2A',
	'\x1b[1;3C', '\x1bOA', '\x1bOD', '\x1ba', '\x1bx', '\x1b\x1b']

// escape sequences cut short or malformed, as a slow link or a confused
// terminal can deliver them
const broken_sequences = ['\x1b[', '\x1b[1;', '\x1bO', '\x1b[<0;', '\x1b[<0;10', '\x1b[200~', '\x1b[201~',
	'\x1b]0;title\x07', '\x1b[?1049h', '\x1b[999999999999A', '\x1b[;;;;;;;;m', '\x1bP', '\x9b',
	'\x1b[1;5', '\x1b[M']

const words = ['fn', 'main', 'return', 'if', 'for', 'struct', 'let', 'const', 'def', 'pub', 'mut',
	'x', 'foo_bar', 'lilly', '0x1F', '3.14', '42', 'true', 'nil']

const punctuation = ['(', ')', '{', '}', '[', ']', '"', "'", '`', '/*', '*/', '//', '#', '\\',
	'<', '>', '=', ';', ',', '.', ':', '$', '@', '%', '&&', '||', '\r', '\r', '\t', ' ', ' ', ' ']

// wide, combining, zero width, right to left and multi-codepoint graphemes:
// everything a column calculation can get wrong
const unicode = ['é', 'ñ', 'ß', '中文', '日本語', '한국어', '😀', '🇬🇧', 'عربى',
	'עברית', 'ｆｕｌｌ', '𝔘𝔫𝔦',
	runes_str([0x1f469, 0x200d, 0x1f469, 0x200d, 0x1f467]), runes_str([`e`, 0x301]),
	runes_str([0x200b]), runes_str([0x200d]), runes_str([0xfeff]), runes_str([0xa0]),
	runes_str([0x2028])]

// runes_str spells out the code points that cannot be seen in source: a
// family emoji joined by zero width joiners, a combining accent, a zero width
// space, a lone joiner, a byte order mark, a no-break space, a line separator
fn runes_str(code_points []rune) string {
	return code_points.string()
}

struct Gen {
mut:
	rng &rand.PRNG
}

fn (mut g Gen) n(max int) int {
	return g.rng.intn(max) or { 0 }
}

fn (mut g Gen) chance(percent int) bool {
	return g.n(100) < percent
}

fn (mut g Gen) pick(items []string) string {
	return items[g.n(items.len)]
}

fn (mut g Gen) delay() int {
	roll := g.n(100)
	if roll < 70 {
		return g.n(6)
	}
	if roll < 95 {
		return 5 + g.n(25)
	}
	return 100 + g.n(300)
}

// text gives something to type in insert mode: code-ish words and brackets
// mixed with awkward unicode, and never a control byte but enter and tab
fn (mut g Gen) text(max int) string {
	mut out := ''
	for _ in 0 .. 1 + g.n(max) {
		roll := g.n(10)
		out += match roll {
			0, 1, 2, 3 { g.pick(words) + ' ' }
			4, 5, 6 { g.pick(punctuation) }
			7 { g.pick(unicode) }
			else { u8(0x21 + g.n(94)).ascii_str() }
		}
	}
	return out
}

fn (mut g Gen) size() (u16, u16) {
	sizes := [[80, 24], [120, 40], [40, 10], [200, 60], [20, 5], [132, 43], [10, 3], [2, 2]]
	s := sizes[g.n(sizes.len)]
	return u16(s[0]), u16(s[1])
}

fn (mut g Gen) keys(s string) Step {
	return Step{
		kind:     .keys
		delay_ms: g.delay()
		bytes:    s.bytes()
	}
}

// typed sends s a key at a time, as a person types it. Bytes that arrive
// together reach lilly as one multi-rune key, so a chord sent whole would
// never be seen as a chord; now and then it is anyway, as a fast typist or a
// paste would deliver it.
fn (mut g Gen) typed(s string) []Step {
	if g.chance(10) {
		return [g.keys(s)]
	}
	return s.runes().map(g.keys(it.str()))
}

// burst returns the steps for one random thing a user, or a terminal, might
// do: weighted toward ordinary editing, with a tail of hostile input
fn (mut g Gen) burst() []Step {
	roll := g.n(100)
	if roll < 26 {
		return [g.keys(g.pick(normal_keys.map(it.ascii_str())))]
	}
	if roll < 30 {
		return [g.keys(ctrl_keys[g.n(ctrl_keys.len)].ascii_str())]
	}
	if roll < 42 {
		return g.typed(g.pick(chords))
	}
	if roll < 54 {
		// typed key by key, as a person would, with escape to leave
		mut steps := [g.keys(g.pick(['i', 'I', 'a', 'A', 'o', 'O']))]
		steps << g.typed(g.text(40))
		steps << g.keys('\x1b')
		return steps
	}
	if roll < 60 {
		mut steps := [g.keys(g.pick(['v', 'V', '\x16']))]
		for _ in 0 .. 1 + g.n(6) {
			steps << g.typed(g.pick(['h', 'j', 'k', 'l', 'w', 'b', 'e', '$', '0', 'G', 'gg', '}',
				'%']))
		}
		steps << g.keys(g.pick(['d', 'y', 'c', '>', '<', '~', 'x', 'p', '\x1b', 'i', 'a']))
		return steps
	}
	if roll < 66 {
		cmd := if g.chance(30) { g.text(12).replace('\r', '') } else { g.pick(commands) }
		mut steps := [g.keys(':')]
		steps << g.typed(cmd)
		steps << g.keys(g.pick(['\r', '\r', '\r', '\x1b']))
		return steps
	}
	if roll < 76 {
		return [g.keys(g.pick(special_keys))]
	}
	if roll < 79 {
		// the file picker, with a query, a move and a choice
		mut steps := [g.keys(';'), g.keys('f'), g.keys('f')]
		for _ in 0 .. g.n(5) {
			steps << g.keys(g.pick(['a', 'e', '.', 'v', 't', '/', '\x7f', '\x1b[A', '\x1b[B']))
		}
		steps << g.keys(g.pick(['\r', '\x1b']))
		return steps
	}
	if roll < 81 {
		return [g.keys('\x1b[200~' + g.text(if g.chance(10) { 4000 } else { 200 }) + '\x1b[201~')]
	}
	if roll < 83 {
		x := 1 + g.n(250)
		y := 1 + g.n(80)
		button := g.pick(['0', '1', '2', '32', '64', '65'])
		return [g.keys('\x1b[<${button};${x};${y}M'), g.keys('\x1b[<${button};${x};${y}m')]
	}
	if roll < 86 {
		mut junk := []u8{len: 1 + g.n(16)}
		g.rng.read(mut junk)
		return [Step{
			kind:     .keys
			delay_ms: g.delay()
			bytes:    junk
		}]
	}
	if roll < 89 {
		return [g.keys(g.pick(broken_sequences))]
	}
	if roll < 93 {
		return [g.keys(g.pick(unicode))]
	}
	if roll < 95 {
		cols, rows := g.size()
		return [Step{
			kind:     .resize
			delay_ms: g.delay()
			cols:     cols
			rows:     rows
		}]
	}
	// a run of digits, a count, before whatever comes next
	return g.typed((1 + g.n(500)).str())
}

// steps generates about `target` steps, with liveness probes among them
fn (mut g Gen) steps(target int) []Step {
	mut out := []Step{}
	for out.len < target {
		out << g.burst()
		if g.n(probe_every) == 0 {
			out << Step{
				kind: .probe
			}
		}
	}
	return out
}
