module buffers

import gap
import line

pub struct TextBuffer {
mut:
	data_buf gap.Buffer
	line_buf line.Buffer
}

pub fn TextBuffer.new() TextBuffer { // TODO(tauraamui) [2026-06-03]: pass in reader into text buffer
	return TextBuffer{
		data_buf: gap.Buffer.new(1024)
		line_buf: line.Buffer.new()
	}
}

pub fn (mut tb TextBuffer) insert(c u8) {
	tb.data_buf.insert(c)
}

pub fn (tb TextBuffer) get_line_bytes(y u64) []u8 {
	line_start, line_end := tb.get_line_start_and_end(y)
	mut line_bytes := []u8{ len: int(line_start + line_end) }
	mut c := 0
	for li in line_start..line_end {
		if c_byte := tb.data_buf.get(li) {
			line_bytes[c] = c_byte
		}
		c += 1
	}
	return line_bytes
}

fn (tb TextBuffer) get_line_start_and_end(y u64) (u64, u64) {
	line_start := tb.line_buf.offsets[y]
	line_end := if y + 1 < tb.line_buf.offsets.len { tb.line_buf.offsets[y + 1] } else { tb.data_buf.logical_len() }
	return line_start, line_end
}


