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

module gap

@[noinit]
pub struct Buffer {
mut:
	buf  []u8
	ccur u64
	cend u64
}

pub fn Buffer.new(size int) Buffer {
	return Buffer{
		buf:  []u8{len: size, cap: size}
		ccur: 0
		cend: u64(size)
	}
}

pub fn (mut gb Buffer) insert(c u8) {
	// NOTE(tauraamui) [2026-06-02]: much prefer the idea the grow only occurs if next insert elapses not before
	if gb.gap_size() == 0 {
		gb.grow()
	}
	gb.buf[gb.ccur] = c
	gb.ccur += u64(1)
}

pub fn (mut gb Buffer) delete() {
	if gb.cend == u64(gb.buf.len) { return }
	gb.cend += 1
}

pub fn (mut gb Buffer) backspace() {
	if gb.ccur == 0 { return }
	gb.ccur -= 1
}

pub fn (mut gb Buffer) move_cur_left() {
	if gb.ccur == 0 { return }
	gb.ccur -= 1
	gb.buf[gb.cend - 1] = gb.buf[gb.ccur]
	gb.buf[gb.ccur] = 0x0
	gb.cend -= 1
}

pub fn (mut gb Buffer) move_cur_right() {
	if gb.cend == u64(gb.buf.len) { return }
	gb.buf[gb.ccur] = gb.buf[gb.cend]
	gb.buf[gb.cend] = 0x0
	gb.ccur += 1
	gb.cend += 1
}

pub fn (mut gb Buffer) move_cur_to_start() {
	if gb.ccur == 0 {
		return
	}
	if gb.cend <= gb.ccur {
		gb.cend = u64(gb.buf.len)
	}
	gap := int(gb.cend - gb.ccur)
	pre_len := int(gb.ccur)
	// one memmove rather than a byte at a time: after loading a file the
	// cursor sits at its end, so this moves the whole file
	copy(mut gb.buf[gap..gap + pre_len], gb.buf[..pre_len])
	cleared := if pre_len < gap { pre_len } else { gap }
	unsafe { vmemset(gb.buf.data, 0, cleared) }
	gb.cend = u64(gap)
	gb.ccur = 0
}

// insert_bytes inserts a run of bytes at the cursor with one copy, growing the
// gap at most once.
pub fn (mut gb Buffer) insert_bytes(bytes []u8) {
	if gb.gap_size() < u64(bytes.len) {
		needed := gb.buf.len + bytes.len - int(gb.gap_size())
		doubled := gb.buf.len * 2
		gb.grow_to(if doubled > needed { doubled } else { needed })
	}
	copy(mut gb.buf[int(gb.ccur)..int(gb.ccur) + bytes.len], bytes)
	gb.ccur += u64(bytes.len)
}

// reserve makes the gap at least n bytes, in a single grow, so a caller that
// knows how much it is about to insert avoids the run of doublings that
// inserting it piecemeal would trigger.
pub fn (mut gb Buffer) reserve(n u64) {
	if gb.gap_size() >= n {
		return
	}
	gb.grow_to(gb.buf.len + int(n - gb.gap_size()))
}

fn (mut gb Buffer) grow() {
	old_len := gb.buf.len
	gb.grow_to(if old_len == 0 { 1 } else { old_len * 2 })
}

fn (mut gb Buffer) grow_to(new_size int) {
	old_len := gb.buf.len
	mut copy_dst := []u8{len: new_size, cap: new_size}
	copy(mut copy_dst[..int(gb.ccur)], gb.buf[..int(gb.ccur)])
	additional := new_size - old_len
	post_gap_len := if old_len > int(gb.cend) { old_len - int(gb.cend) } else { 0 }
	new_gap_end := gb.cend + u64(additional)
	if post_gap_len > 0 {
		copy(mut copy_dst[int(new_gap_end)..int(new_gap_end) + post_gap_len],
			gb.buf[int(gb.cend)..])
	}
	gb.cend = new_gap_end
	gb.buf = copy_dst
}

fn (gb Buffer) gap_size() u64 {
	return gb.cend - gb.ccur
}

pub fn (gb Buffer) ccur() u64 {
	return gb.ccur
}

pub fn (gb Buffer) logical_len() u64 {
	return u64(gb.buf.len - int(gb.gap_size()))
}

pub fn (gb Buffer) get(pos u64) ?u8 {
	offset := u64(if pos < gb.ccur { pos } else { pos + gb.gap_size() })
	if offset >= gb.buf.len { return none }
	return gb.buf[offset]
}

pub fn (gb Buffer) rawstr() string {
	return gb.buf.map(if it == 0x0 { u8(`_`) } else { it }).bytestr()
}

pub fn (gb Buffer) str() string {
	mut copy_dst := []u8{len: gb.buf.len - int(gb.gap_size())}
	copy(mut copy_dst[..gb.ccur], gb.buf[..gb.ccur])
	copy(mut copy_dst[gb.ccur..], gb.buf[gb.cend..])
	return copy_dst.bytestr()
}

pub fn (gb Buffer) left() []u8 {
	return gb.buf[..int(gb.ccur)]
}

pub fn (gb Buffer) right() []u8 {
	return gb.buf[int(gb.cend)..]
}
