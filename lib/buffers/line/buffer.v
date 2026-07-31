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

module line

import arrays

const initial_capacity = 8

@[noinit]
pub struct Buffer {
mut:
	offsets   []i64
	gap_start int
	gap_end   int
	delta     i64
pub mut:
	current_line u64
}

pub fn Buffer.new() Buffer {
	capacity := initial_capacity
	mut offsets := []i64{len: capacity, cap: capacity}
	offsets[0] = 0
	return Buffer{
		offsets:      offsets
		gap_start:    1
		gap_end:      capacity
		delta:        0
		current_line: 0
	}
}

pub fn (lb Buffer) len() int {
	return lb.offsets.len - (lb.gap_end - lb.gap_start)
}

pub fn (lb Buffer) offset_at(index int) u64 {
	if index < 0 || index >= lb.len() {
		return 0
	}
	physical := lb.to_physical_index(index)
	value := lb.offsets[physical]
	if index >= lb.gap_start {
		return clamp_to_u64(value + lb.delta)
	}
	return clamp_to_u64(value)
}

pub fn (mut lb Buffer) apply_delta(amount int) {
	lb.delta += i64(amount)
}

pub fn (mut lb Buffer) insert_after_current(offset u64) {
	lb.ensure_gap(1)
	lb.offsets[lb.gap_start] = i64(offset)
	lb.gap_start += 1
	lb.current_line += 1
}

pub fn (mut lb Buffer) remove_current_line() {
	if lb.current_line == 0 {
		return
	}
	lb.gap_start -= 1
	lb.current_line -= 1
}

pub fn (mut lb Buffer) remove_line_after_current() {
	if lb.current_line + 1 >= u64(lb.len()) {
		return
	}
	if lb.gap_end < lb.offsets.len {
		lb.gap_end += 1
	}
}

pub fn (mut lb Buffer) move_current_line_up() {
	if lb.current_line == 0 {
		return
	}
	lb.current_line -= 1
	lb.move_gap_to_current()
}

pub fn (mut lb Buffer) move_current_line_down() {
	if lb.current_line + 1 >= u64(lb.len()) {
		return
	}
	lb.current_line += 1
	lb.move_gap_to_current()
}

pub fn (mut lb Buffer) move_to_line(line_idx u64) {
	line_count := lb.len()
	if line_count <= 0 {
		lb.current_line = 0
		lb.move_gap_to_current()
		return
	}
	mut target := line_idx
	if target >= u64(line_count) {
		target = u64(line_count - 1)
	}
	lb.current_line = target
	lb.move_gap_to_current()
}

fn (lb Buffer) to_physical_index(index int) int {
	if index < lb.gap_start {
		return index
	}
	return index + (lb.gap_end - lb.gap_start)
}

fn (lb Buffer) gap_size() int {
	return lb.gap_end - lb.gap_start
}

fn (mut lb Buffer) ensure_gap(size int) {
	gap_size := lb.gap_size()
	if gap_size >= size {
		return
	}
	needed := size - gap_size
	mut additional := lb.offsets.len
	if additional < needed {
		additional = needed
	}
	new_len := lb.offsets.len + additional
	mut dest := []i64{len: new_len, cap: new_len}
	arrays.copy(mut dest[..lb.gap_start], lb.offsets[..lb.gap_start])
	after_len := lb.offsets.len - lb.gap_end
	new_gap_end := lb.gap_start + gap_size + additional
	arrays.copy(mut dest[new_gap_end..new_gap_end + after_len], lb.offsets[lb.gap_end..])
	lb.offsets = dest
	lb.gap_end = new_gap_end
}

fn (mut lb Buffer) move_gap_to_current() {
	desired := int(lb.current_line) + 1
	for lb.gap_start < desired {
		lb.shift_gap_right()
	}
	for lb.gap_start > desired {
		lb.shift_gap_left()
	}
}

fn (mut lb Buffer) shift_gap_right() {
	if lb.gap_end >= lb.offsets.len {
		return
	}
	value := lb.offsets[lb.gap_end]
	adjusted := value + lb.delta
	lb.offsets[lb.gap_start] = adjusted
	lb.gap_start += 1
	lb.gap_end += 1
}

fn (mut lb Buffer) shift_gap_left() {
	if lb.gap_start == 0 {
		return
	}
	lb.gap_start -= 1
	value := lb.offsets[lb.gap_start]
	adjusted := value - lb.delta
	lb.gap_end -= 1
	lb.offsets[lb.gap_end] = adjusted
}

fn clamp_to_u64(value i64) u64 {
	if value < 0 {
		return 0
	}
	return u64(value)
}
