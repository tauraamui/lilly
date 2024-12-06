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

fn (mut gap_buffer GapBuffer) insert_rune(r rune) {
	gap_buffer.data[gap_buffer.gap_start] = r
	gap_buffer.gap_start += 1
	gap_buffer.resize_if_full()
}

fn (mut gap_buffer GapBuffer) resize_if_full() {
	if gap_buffer.empty_gap_space_size() != 0 { return }
	size := gap_buffer.data.len * 2
	mut data_dest := []rune{ len: size, cap: size }
	arrays.copy(mut data_dest, gap_buffer.data[..gap_buffer.gap_start])

	gap_start := gap_buffer.gap_start
	gap_end := gap_buffer.gap_start + gap_size

	arrays.copy(mut data_dest[..gap_end], gap_buffer.data[..gap_buffer.gap_end])

	gap_buffer.data = data_dest
	gap_buffer.gap_start = gap_start
	gap_buffer.gap_end = gap_end
}

@[inline]
fn (gap_buffer GapBuffer) empty_gap_space_size() int {
	return gap_buffer.gap_end - gap_buffer.gap_start
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
