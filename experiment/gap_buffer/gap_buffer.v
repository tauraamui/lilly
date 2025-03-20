module main

import strings
import arrays

const gap_size = 6

struct LineTracker {
	line_starts []int
	gap_start   int
	gap_end     int
}

struct Buffer {
	c_buffer      GapBuffer
	line_tracker  LineTracker
	cursor_line   int
	cursor_column int
}

struct GapBuffer {
mut:
	data      []rune
	gap_start int
	gap_end   int
}

fn GapBuffer.new() GapBuffer {
	return GapBuffer{
		data: []rune{ len: gap_size, cap: gap_size }
		gap_start: 0
		gap_end: gap_size
	}
}

pub fn (mut gap_buffer GapBuffer) insert(s string) {
	for r in s.runes() {
		gap_buffer.insert_rune(r)
	}
}

pub fn (mut gap_buffer GapBuffer) backspace() {
	if gap_buffer.gap_start == 0 { return }
	gap_buffer.gap_start -= 1
}

pub fn (mut gap_buffer GapBuffer) delete() {
	if gap_buffer.gap_end + 1 == gap_buffer.data.len { return }
	gap_buffer.gap_end += 1
}

fn (mut gap_buffer GapBuffer) insert_rune(r rune) {
	gap_buffer.data[gap_buffer.gap_start] = r
	gap_buffer.gap_start += 1
	gap_buffer.resize_if_full()
}

fn (mut gap_buffer GapBuffer) move_cursor_left(count int) {
	max_allowed_count := gap_buffer.gap_start
	to_move_count := int_min(count, max_allowed_count)

	for _ in 0..to_move_count {
		gap_buffer.data[gap_buffer.gap_end - 1] = gap_buffer.data[gap_buffer.gap_start - 1]
		gap_buffer.gap_start -= 1
		gap_buffer.gap_end   -= 1
	}
}

fn (mut gap_buffer GapBuffer) move_cursor_right(count int) {
	max_allowed_count := gap_buffer.data.len - gap_buffer.gap_end
	to_move_count := int_min(count, max_allowed_count)

	for _ in 0..to_move_count {
		gap_buffer.data[gap_buffer.gap_start] = gap_buffer.data[gap_buffer.gap_end]
		gap_buffer.gap_start += 1
		gap_buffer.gap_end   += 1
	}
}

fn (mut gap_buffer GapBuffer) resize_if_full() {
	if gap_buffer.empty_gap_space_size() != 0 { return }
	size := gap_buffer.data.len + gap_size
	mut data_dest := []rune{ len: size, cap: size }

	arrays.copy(mut data_dest[..gap_buffer.gap_start], gap_buffer.data[..gap_buffer.gap_start])
	arrays.copy(mut data_dest[gap_buffer.gap_end + (gap_size - (gap_buffer.empty_gap_space_size()))..], gap_buffer.data[gap_buffer.gap_end..])
	gap_buffer.gap_end += gap_size

	gap_buffer.data = data_dest
}

struct LineIterator {
	data       string
mut:
	line_number int
	line_start int
	line_end  int
	done bool
}

fn (mut line_iter LineIterator) next() ?string {
	if line_iter.done {
		line_iter.line_start = 0
		line_iter.line_end = 0
		line_iter.done = false
		return none
	}

	line_iter.line_start = line_iter.line_end

	mut trailing_newline := false
	for c in line_iter.data[line_iter.line_start..].runes() {
		line_iter.line_end += 1
		if c == `\n` {
			trailing_newline = true
			break
		}
	}

	line := line_iter.data[line_iter.line_start..line_iter.line_end - 1]
	if line_iter.line_end == line_iter.data.len && !trailing_newline {
		line_iter.done = true
	} else {
		line_iter.line_number += 1
	}

	return line
}

@[inline]
fn (gap_buffer GapBuffer) empty_gap_space_size() int {
	return gap_buffer.gap_end - gap_buffer.gap_start
}

@[inline]
fn (gap_buffer GapBuffer) str() string {
	return gap_buffer.data[..gap_buffer.gap_start].string() + gap_buffer.data[gap_buffer.gap_end..].string()
}

fn (gap_buffer GapBuffer) raw_str() string {
	mut sb := strings.new_builder(512)
	sb.write_runes(gap_buffer.data[..gap_buffer.gap_start])
	sb.write_string(strings.repeat_string("_", gap_buffer.gap_end - gap_buffer.gap_start))
	sb.write_runes(gap_buffer.data[gap_buffer.gap_end..])
	return sb.str()
}

fn main() {
	println("Hello World!")
	mut gb := GapBuffer.new()
	gb.insert("Hello")
	gb.insert(" Wo")
	gb.insert("rld")
	gb.insert("!")
	println(gb.str())
}
