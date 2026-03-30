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

// Arena is a bump allocator for short-lived, per-frame string allocations.
// Call reset() at the start of each frame to reclaim all memory at once,
// avoiding GC pressure from high-frequency temporary allocations.
struct Arena {
mut:
	buf &u8 = unsafe { nil }
	cap int
	pos int
}

fn Arena.new(size int) Arena {
	return Arena{
		buf: unsafe { malloc(size) }
		cap: size
		pos: 0
	}
}

fn (mut a Arena) reset() {
	a.pos = 0
}

fn (mut a Arena) alloc(n int) ?&u8 {
	aligned := (n + 7) & ~7 // 8-byte align
	if a.pos + aligned > a.cap {
		return none
	}
	ptr := unsafe { a.buf + a.pos }
	a.pos += aligned
	return ptr
}

// dupe_string copies a V string into arena memory, returning a string
// backed by the arena rather than the GC heap.
fn (mut a Arena) dupe_string(s string) string {
	if s.len == 0 {
		return ''
	}
	ptr := a.alloc(s.len + 1) or { return s.clone() }
	unsafe {
		vmemcpy(ptr, s.str, s.len)
		ptr[s.len] = 0
		return tos(ptr, s.len)
	}
}

// runes_to_str encodes a slice of a rune array to a UTF-8 string
// allocated in the arena.
fn (mut a Arena) runes_to_str(runes []rune, start int, end int) string {
	if start >= end {
		return ''
	}
	count := end - start
	max_bytes := count * 4
	ptr := a.alloc(max_bytes + 1) or { return runes[start..end].string() }
	mut pos := 0
	for i in start .. end {
		r := u32(runes[i])
		if r <= 0x7F {
			unsafe {
				ptr[pos] = u8(r)
			}
			pos += 1
		} else if r <= 0x7FF {
			unsafe {
				ptr[pos] = u8(0xC0 | (r >> 6))
				ptr[pos + 1] = u8(0x80 | (r & 0x3F))
			}
			pos += 2
		} else if r <= 0xFFFF {
			unsafe {
				ptr[pos] = u8(0xE0 | (r >> 12))
				ptr[pos + 1] = u8(0x80 | ((r >> 6) & 0x3F))
				ptr[pos + 2] = u8(0x80 | (r & 0x3F))
			}
			pos += 3
		} else {
			unsafe {
				ptr[pos] = u8(0xF0 | (r >> 18))
				ptr[pos + 1] = u8(0x80 | ((r >> 12) & 0x3F))
				ptr[pos + 2] = u8(0x80 | ((r >> 6) & 0x3F))
				ptr[pos + 3] = u8(0x80 | (r & 0x3F))
			}
			pos += 4
		}
	}
	unsafe {
		ptr[pos] = 0
		return tos(ptr, pos)
	}
}

// expand_tabs replaces tab characters with spaces, allocating the result
// in the arena.
fn (mut a Arena) expand_tabs(s string, tw int) string {
	if tw <= 0 || s.len == 0 {
		return s
	}
	// quick scan: if no tabs, return the original string as-is
	mut has_tabs := false
	for i in 0 .. s.len {
		if unsafe { s.str[i] } == 0x09 {
			has_tabs = true
			break
		}
	}
	if !has_tabs {
		return s
	}
	// worst case: every byte is a tab expanding to tw spaces
	max_len := s.len * tw
	ptr := a.alloc(max_len + 1) or { return s.expand_tabs(tw) }
	mut pos := 0
	mut column := 0
	mut i := 0
	for i < s.len {
		b := unsafe { s.str[i] }
		if b == 0x09 {
			spaces := tw - (column % tw)
			for _ in 0 .. spaces {
				unsafe {
					ptr[pos] = 0x20
				}
				pos += 1
			}
			column += spaces
			i += 1
		} else {
			byte_len := if b < 0x80 {
				1
			} else if b < 0xE0 {
				2
			} else if b < 0xF0 {
				3
			} else {
				4
			}
			for j in 0 .. byte_len {
				if i + j < s.len {
					unsafe {
						ptr[pos] = s.str[i + j]
					}
					pos += 1
				}
			}
			column += 1
			i += byte_len
		}
	}
	unsafe {
		ptr[pos] = 0
		return tos(ptr, pos)
	}
}
