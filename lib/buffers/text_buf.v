module buffers

import gap
import line

const newline_hex = 0x0A

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

	for i := tb.line_buf.current_line + 1; i < tb.line_buf.offsets.len; i++ {
		tb.line_buf.offsets[i] += 1
	}

	if c == newline_hex {
		tb.line_buf.offsets.insert(int(tb.line_buf.current_line + 1), tb.data_buf.ccur())
		tb.line_buf.current_line += 1
	}
}

pub fn (mut tb TextBuffer) backspace() {
	c_removed_byte := tb.data_buf.get(tb.data_buf.ccur() - 1) or { return }
	tb.data_buf.backspace()
	if c_removed_byte == newline_hex {
		tb.line_buf.offsets.delete(int(tb.line_buf.current_line))
		tb.line_buf.current_line -= 1
	}

	for i := tb.line_buf.current_line + 1; i < tb.line_buf.offsets.len; i++ {
		tb.line_buf.offsets[i] -= 1
	}
}

pub fn (mut tb TextBuffer) delete() {
	c_removed_byte := tb.data_buf.get(tb.data_buf.ccur()) or { return }
	tb.data_buf.delete()
	if c_removed_byte == newline_hex {
		tb.line_buf.offsets.delete(int(tb.line_buf.current_line + 1))
	}
	for i := tb.line_buf.current_line + 1; i < tb.line_buf.offsets.len; i++ {
		tb.line_buf.offsets[i] -= 1
	}
}

pub fn (mut tb TextBuffer) move_cursor_left() {
	c_byte := tb.data_buf.get(tb.data_buf.ccur() - 1) or { return }
	tb.data_buf.move_cur_left()
	if c_byte == newline_hex {
		tb.line_buf.current_line -= 1
	}
}

pub fn (mut tb TextBuffer) move_cursor_right() {
	c_byte := tb.data_buf.get(tb.data_buf.ccur()) or { return }
	tb.data_buf.move_cur_right()
	if c_byte == newline_hex {
		tb.line_buf.current_line += 1
	}
}

pub fn (tb TextBuffer) get_line_bytes(y u64) ?[]u8 {
	if y >= tb.line_buf.offsets.len { return none }
	line_start, line_end := tb.get_line_start_and_end(y)
	mut line_bytes := []u8{ len: int(line_end - line_start) }
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


