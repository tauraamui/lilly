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
		line_buf: line.Buffer{}
	}
}

pub fn (mut tb TextBuffer) insert_byte(b u8) {
	tb.data_buf.insert(b)
	tb.line_buf.increment()
}


