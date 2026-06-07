
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

pub fn (mut tb TextBuffer) insert_rune(r rune) {
	r_bytes := r.bytes()
	for b in r_bytes {
		tb.insert(b)
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
	cur := tb.data_buf.ccur()
	if cur == 0 {
		return
	}
	start := tb.prev_boundary(cur)
	deleted_newline := tb.data_buf.get(start) or { 0 } == newline_hex
	for _ in start..cur {
		tb.data_buf.backspace()
	}
	tb.line_buf.apply_delta(-int(cur - start))
	if deleted_newline {
		tb.line_buf.remove_current_line()
	}
}

pub fn (mut tb TextBuffer) delete() {
	cur := tb.data_buf.ccur()
	deleted_byte := tb.data_buf.get(cur) or { return }
	end := tb.next_boundary(cur)
	for _ in cur .. end {
		tb.data_buf.delete()
	}
	tb.line_buf.apply_delta(-int(end - cur))
	if deleted_byte == newline_hex {
		tb.line_buf.remove_line_after_current()
	}
}

pub fn (mut tb TextBuffer) move_cursor_left() {
	cur := tb.data_buf.ccur()
	if cur == 0 {
		return
	}
	start := tb.prev_boundary(cur)
	if tb.data_buf.get(start) or { 0 } == newline_hex {
		return
	}
	for _ in start .. cur {
		tb.data_buf.move_cur_left()
	}
}

pub fn (mut tb TextBuffer) move_cursor_right() {
	cur := tb.data_buf.ccur()
	c := tb.data_buf.get(cur) or { return }
	if c == newline_hex {
		return
	}
	end := tb.next_boundary(cur)
	for _ in cur .. end {
		tb.data_buf.move_cur_right()
	}
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
	current_line, _ := tb.cursor_line_and_x()
	if direction < 0 && current_line == 0 {
		return
	}
	if direction > 0 && current_line + 1 >= u64(line_count) {
		return
	}

	// current column measured in codepoints, not bytes
	cur_start, _ := tb.get_line_start_and_end(current_line)
	current_col := tb.count_codepoints(cur_start, tb.data_buf.ccur())

	target_line := if direction < 0 { current_line - 1 } else { current_line + 1 }
	target_start, target_end := tb.get_line_start_and_end(target_line)

	// trim trailing newline from the target line's content
	mut content_end := target_end
	if content_end > target_start {
		if last := tb.data_buf.get(content_end - 1) {
			if last == newline_hex {
				content_end -= 1
			}
		}
	}

	// resolve target column (in codepoints) back to a byte offset
	target_offset := tb.offset_at_column(target_start, content_end, current_col)

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

fn (tb TextBuffer) codepoint_len_at(offset u64) ?int {
	lead := tb.data_buf.get(offset) or { return none }
	desired := utf8_codepoint_len(lead)

	// only count continuation bytes that are actually present and valid
	mut actual := 1
	for actual < desired {
		next := tb.data_buf.get(offset + u64(actual)) or { break }
		if !is_utf8_continuation_byte(next) {
			break
		}
		actual += 1
	}
	return actual
}

fn (tb TextBuffer) prev_codepoint_boundary(offset u64) u64 {
	if offset == 0 {
		return 0
	}
	mut i := offset - 1
	for i > 0 {
		b := tb.data_buf.get(i) or { break }
		if !is_utf8_continuation_byte(b) {
			break
		}
		i -= 1
	}
	return i
}

fn (tb TextBuffer) next_codepoint_boundary(offset u64) u64 {
	len := tb.codepoint_len_at(offset) or { return offset }
	return offset + u64(len)
}

// grapheme-cluster aware boundaries: cover combining marks U+0300..U+036F,
// ZWJ U+200D, and variation selectors U+FE00..U+FE0F.
fn (tb TextBuffer) prev_boundary(offset u64) u64 {
	if offset == 0 {
		return 0
	}
	mut o := tb.prev_codepoint_boundary(offset)
	for o > 0 {
		if tb.is_extender_at(o) {
			o = tb.prev_codepoint_boundary(o)
			continue
		}
		prev_cp := tb.prev_codepoint_boundary(o)
		if tb.is_zwj_at(prev_cp) {
			before_zwj := tb.prev_codepoint_boundary(prev_cp)
			o = before_zwj
			continue
		}
		break
	}
	return o
}

fn (tb TextBuffer) next_boundary(offset u64) u64 {
	mut o := tb.next_codepoint_boundary(offset)
	if o == offset {
		return o
	}
	for {
		if tb.is_zwj_at(o) {
			after_zwj := tb.next_codepoint_boundary(o)
			if after_zwj == o {
				break
			}
			next_cp := tb.next_codepoint_boundary(after_zwj)
			if next_cp == after_zwj {
				break
			}
			o = next_cp
			continue
		}
		if tb.is_extender_at(o) {
			next_cp := tb.next_codepoint_boundary(o)
			if next_cp == o {
				break
			}
			o = next_cp
			continue
		}
		break
	}
	return o
}

fn (tb TextBuffer) is_zwj_at(offset u64) bool {
	c0 := tb.data_buf.get(offset) or { return false }
	if c0 != 0xE2 {
		return false
	}
	c1 := tb.data_buf.get(offset + 1) or { return false }
	c2 := tb.data_buf.get(offset + 2) or { return false }
	return c1 == 0x80 && c2 == 0x8D
}

fn (tb TextBuffer) is_extender_at(offset u64) bool {
	c0 := tb.data_buf.get(offset) or { return false }
	// U+0300..U+036F combining diacriticals: CC 80..BF, CD 80..AF
	if c0 == 0xCC {
		c1 := tb.data_buf.get(offset + 1) or { return false }
		return c1 >= 0x80 && c1 <= 0xBF
	}
	if c0 == 0xCD {
		c1 := tb.data_buf.get(offset + 1) or { return false }
		return c1 >= 0x80 && c1 <= 0xAF
	}
	// U+200D ZWJ: E2 80 8D
	if c0 == 0xE2 {
		c1 := tb.data_buf.get(offset + 1) or { return false }
		c2 := tb.data_buf.get(offset + 2) or { return false }
		if c1 == 0x80 && c2 == 0x8D {
			return true
		}
	}
	// U+FE00..U+FE0F variation selectors: EF B8 80..8F
	if c0 == 0xEF {
		c1 := tb.data_buf.get(offset + 1) or { return false }
		c2 := tb.data_buf.get(offset + 2) or { return false }
		if c1 == 0xB8 && c2 >= 0x80 && c2 <= 0x8F {
			return true
		}
	}
	return false
}

// count grapheme clusters in the byte range [start, end)
fn (tb TextBuffer) count_codepoints(start u64, end u64) u64 {
	mut count := u64(0)
	mut offset := start
	for offset < end {
		offset = tb.next_boundary(offset)
		count += 1
	}
	return count
}

// walk `cols` codepoints forward from `start`, but never past `limit`
fn (tb TextBuffer) offset_at_column(start u64, limit u64, cols u64) u64 {
	mut offset := start
	mut moved := u64(0)
	for moved < cols && offset < limit {
		offset = tb.next_boundary(offset)
		moved += 1
	}
	return offset
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
		return 0, tb.count_codepoints(0, tb.data_buf.ccur())
	}
	mut line_idx := tb.line_buf.current_line
	if line_idx >= u64(line_count) {
		line_idx = u64(line_count - 1)
	}
	line_start, _ := tb.get_line_start_and_end(line_idx)
	cursor_offset := tb.data_buf.ccur()
	column := if cursor_offset >= line_start {
		tb.count_codepoints(line_start, cursor_offset)
	} else {
		u64(0)
	}
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

pub fn (mut tb TextBuffer) move_cursor_to_previous_blank_line() {
	current_line, _ := tb.cursor_line_and_x()
	if current_line == 0 {
		return
	}
	mut target := i64(-1)
	mut i := i64(current_line) - 1
	for i >= 0 {
		if tb.is_blank_line(u64(i)) {
			target = i
			break
		}
		i -= 1
	}
	if target < 0 {
		return
	}
	tb.move_cursor_to_line_start(u64(target))
}

pub fn (mut tb TextBuffer) move_cursor_to_next_blank_line() {
	line_count := u64(tb.line_buf.len())
	current_line, _ := tb.cursor_line_and_x()
	if current_line + 1 >= line_count {
		return
	}
	mut target := i64(-1)
	for i in current_line + 1 .. line_count {
		if tb.is_blank_line(i) {
			target = i64(i)
			break
		}
	}
	if target < 0 {
		return
	}
	tb.move_cursor_to_line_start(u64(target))
}

fn (tb TextBuffer) is_blank_line(y u64) bool {
	line_start, line_end := tb.get_line_start_and_end(y)
	span := line_end - line_start
	if span == 0 {
		return true
	}
	if span == 1 {
		if b := tb.data_buf.get(line_start) {
			return b == newline_hex
		}
	}
	return false
}

fn (mut tb TextBuffer) move_cursor_to_line_start(y u64) {
	line_start, _ := tb.get_line_start_and_end(y)
	current_offset := tb.data_buf.ccur()
	if line_start > current_offset {
		for _ in 0 .. line_start - current_offset {
			tb.data_buf.move_cur_right()
		}
	} else if line_start < current_offset {
		for _ in 0 .. current_offset - line_start {
			tb.data_buf.move_cur_left()
		}
	}
	tb.line_buf.move_to_line(y)
}

pub fn (mut tb TextBuffer) move_cursor_to_start() {
	tb.data_buf.move_cur_to_start()
	tb.line_buf.move_to_line(0)
}

fn is_utf8_continuation_byte(b u8) bool {
	return b & 0b1100_0000 == 0b1000_0000
}

fn utf8_codepoint_len(lead u8) int {
	if lead & 0b1000_0000 == 0 {
		return 1
	}
	if lead & 0b1110_0000 == 0b1100_0000 {
		return 2
	}
	if lead & 0b1111_0000 == 0b1110_0000 {
		return 3
	}
	if lead & 0b1111_1000 == 0b1111_0000 {
		return 4
	}
	return 1 // invalid lead byte: treat as a single byte
}


