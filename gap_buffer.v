module buffers

import arrays

pub struct GapBuffer {
	initial_gap_size u32
mut:
	data      []rune
	gap_start u32
	gap_end   u32
}

const null_code_point = rune(0xfeff)
const initial_gap_size = u32(32)

@[params]
pub struct GapBufferParams {
	content  []rune
	gap_size u32 = initial_gap_size
}

pub fn GapBuffer.new(opts GapBufferParams) GapBuffer {
	mut gb := GapBuffer{
		initial_gap_size: opts.gap_size
		data: []rune{ len: opts.content.len + int(opts.gap_size), init: null_code_point }
		gap_start: 0
		gap_end: opts.gap_size
	}
	gb.initial_fill(opts.content)
	return gb
}

fn (mut g GapBuffer) initial_fill(data []rune) {
	for i, c in data {
		g.data[int(g.gap_end) + i] = c
	}
}

fn (mut g GapBuffer) grow_gap() {
	mut dest := []rune{ len: g.data.len + int(g.initial_gap_size), init: null_code_point }
	arrays.copy(mut dest[..g.gap_start], g.data[..g.gap_start])
	gap_end := g.gap_start + g.initial_gap_size
	arrays.copy(mut dest[gap_end..], g.data[g.gap_end..])
	g.gap_end = gap_end
	g.data = dest
}

fn (mut g GapBuffer) move_gap(position int) {
	if position == g.gap_start {
		return
	}

	if position > g.gap_start {
		chars_to_move := position - int(g.gap_start)
		for i in 0..chars_to_move {
			g.data[int(g.gap_start) + i] = g.data[int(g.gap_end) + i]
			g.data[int(g.gap_end) + i] = null_code_point
		}
		g.gap_start = u32(position)
		g.gap_end += u32(chars_to_move)
		return
	}

	chars_to_move := int(g.gap_start) - position
	for i := chars_to_move - 1; i >= 0; i-- {
		g.data[int(g.gap_end) - chars_to_move + i] = g.data[position + i]
		g.data[position + i] = null_code_point
	}
	g.gap_end -= u32(chars_to_move)
	g.gap_start = u32(position)
}

fn (g GapBuffer) current_gap_size() u32 {
	return u32(g.gap_end - g.gap_start)
}

pub fn (mut g GapBuffer) insert_char(data rune) {
	if g.current_gap_size() == 0 {
		g.grow_gap()
	}
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

