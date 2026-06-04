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
	if tb.data_buf.ccur() == 0 {
		return
	}

	mut start_index := tb.data_buf.ccur() - 1
	mut start_byte := tb.data_buf.get(start_index) or { return }
	for start_index > 0 && is_utf8_continuation_byte(start_byte) {
		start_index -= 1
		start_byte = tb.data_buf.get(start_index) or { break }
	}

	if start_byte == newline_hex {
		return
	}

	char_len := int(tb.data_buf.ccur() - start_index)
	for _ in 0 .. char_len {
		if tb.data_buf.ccur() == 0 {
			break
		}
		tb.data_buf.move_cur_left()
	}

}

pub fn (mut tb TextBuffer) move_cursor_right() {
	start := tb.data_buf.ccur()
	start_byte := tb.data_buf.get(start) or { return }
	if start_byte == newline_hex {
		return
	}

	mut desired_len := utf8_codepoint_len(start_byte)
	if desired_len < 1 {
		desired_len = 1
	}

	mut actual_len := 1
	for actual_len < desired_len {
		next_index := start + u64(actual_len)
		next_byte := tb.data_buf.get(next_index) or { break }
		if !is_utf8_continuation_byte(next_byte) {
			break
		}
		actual_len += 1
	}

	for _ in 0 .. actual_len {
		if tb.data_buf.get(tb.data_buf.ccur()) == none {
			break
		}
		tb.data_buf.move_cur_right()
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
	if line_bytes.len == 1 && line_bytes[0] == newline_hex {
		return []u8{}
	}
	return line_bytes
}

pub fn (tb TextBuffer) cursor_line_and_x() (u64, u64) {
	line_count := tb.line_buf.len()
	if line_count == 0 {
		return 0, tb.data_buf.ccur()
	}
	mut line_idx := tb.line_buf.current_line
	if line_idx >= u64(line_count) {
		line_idx = u64(line_count - 1)
	}
	line_start, _ := tb.get_line_start_and_end(line_idx)
	cursor_offset := tb.data_buf.ccur()
	column := if cursor_offset >= line_start { cursor_offset - line_start } else { 0 }
	return line_idx, column
}

pub fn (tb TextBuffer) line_count() u64 {
	return u64(tb.line_buf.len())
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

fn is_utf8_continuation_byte(b u8) bool {
	return b & 0b11000000 == 0b10000000
}

fn utf8_codepoint_len(start_byte u8) int {
	if start_byte & 0b10000000 == 0 {
		return 1
	}
	if start_byte & 0b11100000 == 0b11000000 {
		return 2
	}
	if start_byte & 0b11110000 == 0b11100000 {
		return 3
	}
	if start_byte & 0b11111000 == 0b11110000 {
		return 4
	}
	return 1
}

