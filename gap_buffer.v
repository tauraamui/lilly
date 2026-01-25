module buffers

pub struct GapBuffer {
mut:
	data      []rune
	gap_start u32
	gap_end   u32
}

const null_code_point = rune(0xfeff)
const initial_gap_size = 32

pub fn GapBuffer.new(content []rune) GapBuffer {
	mut gb := GapBuffer{
		data: []rune{ len: content.len + initial_gap_size, init: null_code_point }
		gap_start: 0
		gap_end: initial_gap_size
	}
	gb.initial_fill(content)
	return gb
}

pub fn (mut g GapBuffer) initial_fill(data []rune) {
	for i, c in data {
		g.data[int(g.gap_end) + i] = c
	}
}

pub fn (mut g GapBuffer) insert_char(data rune) {
	g.data[g.gap_start] = data
	g.gap_start += 1
}

pub fn (g GapBuffer) content() string {
	pre_gap := g.data[..g.gap_start]
	post_gap := g.data[g.gap_end..]
	return pre_gap.string() + post_gap.string()
}

pub fn (g GapBuffer) raw_content() []rune {
	return g.data
}

fn null_code_point_to_str(c rune) rune {
	return if c == null_code_point { `_` } else { c }
}

