module buffers

pub struct GapBuffer {
mut:
	data      []rune
	gap_start u32
	gap_size  u32
}

const null_code_point = rune(0xfeff)
const initial_gap_size = 32

pub fn GapBuffer.new(content []rune) GapBuffer {
	mut gb := GapBuffer{
		data: []rune{ len: content.len + initial_gap_size, init: null_code_point }
		gap_start: 0
		gap_size: initial_gap_size
	}
	gb.insert(content)
	return gb
}

pub fn (mut g GapBuffer) insert(data []rune) {
	for i, c in data {
		g.data[int(g.gap_start + g.gap_size) + i] = c
	}
}

pub fn (g GapBuffer) content() string {
	return g.data[g.gap_start + g.gap_size..].string()
}

pub fn (g GapBuffer) raw_content() []rune {
	return g.data
}

fn null_code_point_to_str(c rune) rune {
	return if c == null_code_point { `_` } else { c }
}

