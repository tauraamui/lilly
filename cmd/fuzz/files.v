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

import os

// every extension lilly has a lexer for, plus some it does not, so a file's
// content is also lexed by grammars it was never written for
const extensions = ['.v', '.py', '.c', '.h', '.go', '.rs', '.js', '.ts', '.zig', '.pl', '.gleam',
	'.md', '.txt', '', '.json', '.toml']

struct CorpusFile {
	name string
	data []u8
}

fn load_corpus(dirs []string) []CorpusFile {
	mut out := []CorpusFile{}
	for dir in dirs {
		mut entries := os.ls(dir) or {
			eprintln('fuzz: skipping corpus ${dir}: ${err}')
			continue
		}
		// os.ls lists in the filesystem's order, so without sorting a session
		// seed from CI picks different files here and replays nothing like it
		entries.sort()
		for entry in entries {
			path := os.join_path(dir, entry)
			if os.is_dir(path) {
				continue
			}
			data := os.read_bytes(path) or { continue }
			out << CorpusFile{
				name: entry
				data: data
			}
		}
	}
	return out
}

// file returns a name and contents for lilly to open: a corpus file, often
// mutated and sometimes renamed to another language, or one made from nothing
fn (mut g Gen) file(corpus []CorpusFile) CorpusFile {
	if corpus.len == 0 || g.chance(8) {
		return CorpusFile{
			name: 'made${g.pick(extensions)}'
			data: g.made_file()
		}
	}
	base := corpus[g.n(corpus.len)]
	mut name := base.name
	if g.chance(30) {
		name = os.file_name(name).all_before_last('.') + g.pick(extensions)
	}
	mut data := base.data.clone()
	for _ in 0 .. g.n(4) {
		data = g.mutate(data, corpus)
	}
	return CorpusFile{
		name: name
		data: data
	}
}

fn (mut g Gen) made_file() []u8 {
	roll := g.n(8)
	return match roll {
		0 { []u8{} }
		1 { '\n'.bytes() }
		2 { 'x'.repeat(200_000).bytes() }
		3 { 'line\n'.repeat(20_000).bytes() }
		4 { '('.repeat(5_000).bytes() }
		5 { '\t\t\t\t\t\t\t\t'.repeat(2_000).bytes() }
		6 { '/*'.repeat(3_000).bytes() }
		else { g.text(2_000).replace('\r', '\n').bytes() }
	}
}

fn (mut g Gen) mutate(data []u8, corpus []CorpusFile) []u8 {
	mut out := data.clone()
	at := if out.len == 0 { 0 } else { g.n(out.len) }
	roll := g.n(13)
	match roll {
		0 {
			// flip some bits
			for _ in 0 .. 1 + g.n(8) {
				if out.len == 0 {
					break
				}
				i := g.n(out.len)
				out[i] ^= u8(1 << g.n(8))
			}
		}
		1 {
			mut junk := []u8{len: 1 + g.n(32)}
			g.rng.read(mut junk)
			out.insert(at, junk)
		}
		2 {
			if out.len > 0 {
				end := at + g.n(out.len - at + 1)
				out = out[..at].clone()
				out << data[end..]
			}
		}
		3 {
			// cut mid file, often mid character
			out = out[..at].clone()
		}
		4 {
			// invalid and overlong UTF-8, a lone surrogate, a stray continuation byte
			bad := [[u8(0xff)], [u8(0xc0), 0x80], [u8(0xed), 0xa0, 0x80], [u8(0x80)],
				[u8(0xf4), 0x90, 0x80, 0x80], [u8(0xe2), 0x82]]
			out.insert(at, bad[g.n(bad.len)])
		}
		5 {
			out.insert(at, u8(0))
		}
		6 {
			out = out.bytestr().replace('\n', '\r\n').bytes()
		}
		7 {
			out = out.bytestr().replace('\n', '\r').bytes()
		}
		8 {
			out.insert(at, 'y'.repeat(10_000 + g.n(100_000)).bytes())
		}
		9 {
			out.insert(at, g.pick(unicode).repeat(1 + g.n(500)).bytes())
		}
		10 {
			// splice in part of another file, often of another language
			other := corpus[g.n(corpus.len)].data
			if other.len > 0 {
				from := g.n(other.len)
				out.insert(at, other[from..from + g.n(other.len - from + 1)])
			}
		}
		11 {
			// open a comment, string or block and never close it
			out.insert(at, g.pick(['/*', '"', "'", '`', '{', '(', '[', '"""', '```', '<!--', '=pod\n']).bytes())
		}
		else {
			out.insert(0, [u8(0xef), 0xbb, 0xbf])
		}
	}
	// keep runs quick: a file this size already exercises every long-file path
	if out.len > 2_000_000 {
		out = out[..2_000_000].clone()
	}
	return out
}
