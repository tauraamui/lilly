
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
	c := tb.data_buf.get(tb.data_buf.ccur() - 1) or { return }
	tb.data_buf.backspace()
	tb.line_buf.apply_delta(-1)
	if c == newline_hex {
		tb.line_buf.remove_current_line()
	}
}

pub fn (mut tb TextBuffer) delete() {
	c := tb.data_buf.get(tb.data_buf.ccur()) or { return }
	tb.data_buf.delete()
	tb.line_buf.apply_delta(-1)
	if c == newline_hex {
		tb.line_buf.remove_line_after_current()
	}
}

pub fn (mut tb TextBuffer) move_cursor_left() {
	if tb.data_buf.ccur() == 0 {
		return
	}
	c := tb.data_buf.get(tb.data_buf.ccur() - 1) or { return }
	if c == newline_hex {
		return
	}
	tb.data_buf.move_cur_left()
}

pub fn (mut tb TextBuffer) move_cursor_right() {
	c := tb.data_buf.get(tb.data_buf.ccur()) or { return }
	if c == newline_hex {
		return
	}
	tb.data_buf.move_cur_right()
}

pub fn (mut tb TextBuffer) move_cursor_up() {
	tb.move_cursor_vertical(-1)
}

pub fn (mut tb TextBuffer) move_cursor_down() {
	tb.move_cursor_vertical(1)
}

fn (mut tb TextBuffer) move_cursor_vertical(direction int) {
	line_count := tb.line_buf.len()
	if line_count == 0 {
		return
	}
	current_line, current_col := tb.cursor_line_and_x()
	if direction < 0 && current_line == 0 {
		return
	}
	if direction > 0 && current_line + 1 >= u64(line_count) {
		return
	}
	target_line := if direction < 0 { current_line - 1 } else { current_line + 1 }
	target_start, target_end := tb.get_line_start_and_end(target_line)
	mut content_len := target_end - target_start
	if content_len > 0 {
		if last := tb.data_buf.get(target_end - 1) {
			if last == newline_hex {
				content_len -= 1
			}
		}
	}
	target_col := if current_col < content_len { current_col } else { content_len }
	target_offset := target_start + target_col
	current_offset := tb.data_buf.ccur()
	if target_offset > current_offset {
		for _ in 0 .. target_offset - current_offset {
			tb.data_buf.move_cur_right()
		}
	} else if target_offset < current_offset {
		for _ in 0 .. current_offset - target_offset {
			tb.data_buf.move_cur_left()
		}
	}
	tb.line_buf.move_to_line(target_line)
}

pub fn (tb TextBuffer) get_line_bytes(y u64) ?[]u8 {
	line_count := tb.line_buf.len()
	if y >= u64(line_count) {
		return none
	}
	line_start, line_end := tb.get_line_start_and_end(y)
	mut line_bytes := []u8{len: int(line_end - line_start)}
	mut c := 0
	for li in line_start .. line_end {
		if c_byte := tb.data_buf.get(li) {
			line_bytes[c] = c_byte
		}
		c += 1
	}
	if line_bytes.len > 0 && line_bytes[line_bytes.len - 1] == newline_hex {
		return line_bytes[..line_bytes.len - 1]
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
	line_end := if y + 1 < u64(line_count) {
		tb.line_buf.offset_at(int(y + 1))
	} else {
		tb.data_buf.logical_len()
	}
	return line_start, line_end
}

pub fn (mut tb TextBuffer) move_cursor_to_start() {
	tb.data_buf.move_cur_to_start()
	tb.line_buf.move_to_line(0)
}


