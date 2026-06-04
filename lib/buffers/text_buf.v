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
	tb.line_buf.apply_delta(1)
	if c == newline_hex {
		tb.line_buf.insert_after_current(tb.data_buf.ccur())
	}
}

pub fn (mut tb TextBuffer) backspace() {
	if tb.data_buf.ccur() == 0 {
		return
	}
	c_removed_byte := tb.data_buf.get(tb.data_buf.ccur() - 1) or { return }
	tb.data_buf.backspace()
	tb.line_buf.apply_delta(-1)
	if c_removed_byte == newline_hex {
		tb.line_buf.remove_current_line()
	}
}

pub fn (mut tb TextBuffer) delete() {
	c_removed_byte := tb.data_buf.get(tb.data_buf.ccur()) or { return }
	tb.data_buf.delete()
	tb.line_buf.apply_delta(-1)
	if c_removed_byte == newline_hex {
		tb.line_buf.remove_line_after_current()
	}
}

pub fn (mut tb TextBuffer) move_cursor_left() {
	c_byte := tb.data_buf.get(tb.data_buf.ccur() - 1) or { return }
	tb.data_buf.move_cur_left()
	if c_byte == newline_hex {
		tb.line_buf.move_current_line_up()
	}
}

pub fn (mut tb TextBuffer) move_cursor_right() {
	c_byte := tb.data_buf.get(tb.data_buf.ccur()) or { return }
	tb.data_buf.move_cur_right()
	if c_byte == newline_hex {
		tb.line_buf.move_current_line_down()
	}
}

pub fn (tb TextBuffer) get_line_bytes(y u64) ?[]u8 {
	line_count := tb.line_buf.len()
	if y >= u64(line_count) { return none }
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
	line_count := tb.line_buf.len()
	line_start := tb.line_buf.offset_at(int(y))
	line_end := if y + 1 < u64(line_count) { tb.line_buf.offset_at(int(y + 1)) } else { tb.data_buf.logical_len() }
	return line_start, line_end
}

pub fn (mut tb TextBuffer) move_cursor_to_start() {
	tb.data_buf.move_cur_to_start()
	tb.line_buf.move_to_line(0)
}

