module main

import strings

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

fn (mut gap_buffer GapBuffer) insert(s string) {
	for r in s.runes() {
		gap_buffer.insert_rune(r)
	}
}

fn (mut gap_buffer GapBuffer) insert_rune(r rune) {
	gap_buffer.data[gap_buffer.gap_start] = r
	gap_buffer.gap_start += 1
}

fn (gap_buffer GapBuffer) str() string {
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
	gb.insert("Wo")
	println(gb.str())
}
