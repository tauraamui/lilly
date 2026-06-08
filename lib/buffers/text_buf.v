module buffers

import encoding.utf8
import gap
import line

const newline_hex = 0x0A
const space_hex   = 0x20
const tab_hex     = 0x09

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

pub fn (mut tb TextBuffer) delete_line(y u64) {
	line_count := u64(tb.line_buf.len())
	if y >= line_count {
		return
	}
	is_last := y + 1 == line_count
	has_prev := y > 0
	line_start, line_end := tb.get_line_start_and_end(y)
	byte_count := line_end - line_start
	tb.move_cursor_to_line_start(y)
	for _ in 0..byte_count {
		tb.delete()
	}
	// Vim collapse: when the deleted line was the last in the file, also
	// consume the preceding line's terminating newline so we don't leave
	// behind an empty trailing line. Skipped for the only-line case —
	// the buffer must always contain at least one line.
	if is_last && has_prev {
		tb.backspace()
		tb.move_cursor_to_line_start(y - 1)
	}
}

// delete_range removes graphemes in the half-open span
// [(start_y, start_x), (end_y, end_x)). Positions are given in
// (line, grapheme-column) terms — the same units `cursor_line_and_x`
// returns — so callers can pass values straight from a resolved motion
// range. Endpoints in document order are normalized; an inverted range
// is treated as the same span. Out-of-range lines are clamped to the
// last line; columns past line content are clamped to the line's end
// (excluding the terminating newline). When the span crosses a
// newline, the underlying delete() handles line-buffer accounting, so
// joins happen automatically.
pub fn (mut tb TextBuffer) delete_range(start_y u64, start_x u64, end_y u64, end_x u64) {
	line_count := u64(tb.line_buf.len())
	if line_count == 0 {
		return
	}
	mut sy, mut sx := start_y, start_x
	mut ey, mut ex := end_y, end_x
	if sy > ey || (sy == ey && sx > ex) {
		sy, sx = end_y, end_x
		ey, ex = start_y, start_x
	}
	if sy >= line_count {
		return
	}
	if ey >= line_count {
		ey = line_count - 1
		ex = u64(tb.line_graphemes(ey).len)
	}
	start_offset := tb.byte_offset_at(sy, sx)
	end_offset := tb.byte_offset_at(ey, ex)
	if end_offset <= start_offset {
		return
	}
	grapheme_count := tb.count_graphemes(start_offset, end_offset)
	tb.move_cursor_to_position(sy, sx)
	for _ in 0 .. grapheme_count {
		tb.delete()
	}
}

fn (tb TextBuffer) byte_offset_at(y u64, x u64) u64 {
	line_start, line_end := tb.get_line_start_and_end(y)
	mut content_end := line_end
	if content_end > line_start {
		if last := tb.data_buf.get(content_end - 1) {
			if last == newline_hex {
				content_end -= 1
			}
		}
	}
	return tb.offset_at_column(line_start, content_end, x)
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
	current_col := tb.count_graphemes(cur_start, tb.data_buf.ccur())

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
fn (tb TextBuffer) count_graphemes(start u64, end u64) u64 {
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
		return 0, tb.count_graphemes(0, tb.data_buf.ccur())
	}
	mut line_idx := tb.line_buf.current_line
	if line_idx >= u64(line_count) {
		line_idx = u64(line_count - 1)
	}
	line_start, _ := tb.get_line_start_and_end(line_idx)
	cursor_offset := tb.data_buf.ccur()
	column := if cursor_offset >= line_start {
		tb.count_graphemes(line_start, cursor_offset)
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
		target = 0
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
		target = i64(line_count - 1)
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

pub fn (tb TextBuffer) resolve_prev_line_whitespace_prefix() []u8 {
	line_count := tb.line_buf.len()
	if line_count == 0 {
		return []
	}
	mut line_idx := tb.line_buf.current_line
	if line_idx >= u64(line_count) {
		line_idx = u64(line_count - 1)
	}
	line_start, line_end := tb.get_line_start_and_end(line_idx)
	mut prefix := []u8{}
	for o := line_start; o < line_end; o++ {
		b := tb.data_buf.get(o) or { break }
		if b == newline_hex {
			break
		}
		if b != space_hex && b != tab_hex {
			break
		}
		prefix << b
	}
	return prefix
}

pub fn (mut tb TextBuffer) jump_cursor_to_line_end() {
	line_count := tb.line_buf.len()
	if line_count == 0 {
		return
	}
	mut line_idx := tb.line_buf.current_line
	if line_idx >= u64(line_count) {
		line_idx = u64(line_count - 1)
	}
	line_start, line_end := tb.get_line_start_and_end(line_idx)
	mut target := line_end
	if target > line_start {
		if last := tb.data_buf.get(target - 1) {
			if last == newline_hex {
				target -= 1
			}
		}
	}
	current_offset := tb.data_buf.ccur()
	if target > current_offset {
		for _ in 0 .. target - current_offset {
			tb.data_buf.move_cur_right()
		}
	} else if target < current_offset {
		for _ in 0 .. current_offset - target {
			tb.data_buf.move_cur_left()
		}
	}
}

enum CharType {
	alpha_num
	whitespace
	other
}

fn char_type(c rune) CharType {
	return match true {
		utf8.is_space(c) { .whitespace }
		is_alpha_num(c) { .alpha_num }
		else { .other }
	}
}

fn is_alpha_num(c rune) bool {
	return utf8.is_letter(c) || utf8.is_number(c) || c == `_`
}

pub fn (tb TextBuffer) line_graphemes(y u64) []string {
	line_start, line_end := tb.get_line_start_and_end(y)
	mut end := line_end
	if end > line_start {
		if last := tb.data_buf.get(end - 1) {
			if last == newline_hex {
				end -= 1
			}
		}
	}
	mut result := []string{}
	mut offset := line_start
	for offset < end {
		next := tb.next_boundary(offset)
		if next <= offset {
			break
		}
		mut bytes := []u8{len: int(next - offset)}
		for i in 0 .. bytes.len {
			if b := tb.data_buf.get(offset + u64(i)) {
				bytes[i] = b
			}
		}
		result << bytes.bytestr()
		offset = next
	}
	return result
}

fn grapheme_char_type(g string) CharType {
	if g.len == 0 {
		return .other
	}
	first := g.runes()[0]
	return char_type(first)
}

fn grapheme_is_space(g string) bool {
	if g.len == 0 {
		return false
	}
	return utf8.is_space(g.runes()[0])
}

fn (mut tb TextBuffer) move_cursor_to_position(y u64, x u64) {
	line_count := tb.line_buf.len()
	if y >= u64(line_count) {
		return
	}
	line_start, line_end := tb.get_line_start_and_end(y)
	mut content_end := line_end
	if content_end > line_start {
		if last := tb.data_buf.get(content_end - 1) {
			if last == newline_hex {
				content_end -= 1
			}
		}
	}
	target_offset := tb.offset_at_column(line_start, content_end, x)
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
	tb.line_buf.move_to_line(y)
}

pub fn (mut tb TextBuffer) move_cursor_to_next_word_start() {
	src_y, start_x := tb.cursor_line_and_x()
	line_count := tb.line_buf.len()
	mut y := src_y
	mut x := start_x
	for {
		if pos := scan_to_next_word_start(tb.line_graphemes(y), int(x), int(y), int(src_y)) {
			tb.move_cursor_to_position(u64(pos.y), u64(pos.x))
			return
		}
		next_y := y + 1
		if next_y >= u64(line_count) {
			return
		}
		y = next_y
		x = 0
	}
}

pub fn (mut tb TextBuffer) move_cursor_to_previous_word_start() {
	src_y, start_x := tb.cursor_line_and_x()
	mut y := src_y
	mut x := start_x
	for {
		if pos := scan_to_previous_word_start(tb.line_graphemes(y), int(x), int(y), int(src_y)) {
			tb.move_cursor_to_position(u64(pos.y), u64(pos.x))
			return
		}
		if y == 0 {
			return
		}
		y -= 1
		prev_graphemes := tb.line_graphemes(y)
		x = if prev_graphemes.len == 0 { u64(0) } else { u64(prev_graphemes.len - 1) }
	}
}

pub fn (mut tb TextBuffer) move_cursor_to_next_word_end() {
	src_y, start_x := tb.cursor_line_and_x()
	line_count := tb.line_buf.len()
	mut y := src_y
	mut x := start_x
	for {
		if pos := scan_to_next_word_end(tb.line_graphemes(y), int(x), int(y), int(src_y)) {
			tb.move_cursor_to_position(u64(pos.y), u64(pos.x))
			return
		}
		next_y := y + 1
		if next_y >= u64(line_count) {
			return
		}
		y = next_y
		x = 0
	}
}

pub fn (mut tb TextBuffer) move_cursor_to_previous_word_end() {
	src_y, start_x := tb.cursor_line_and_x()
	mut y := src_y
	mut x := start_x
	for {
		if pos := scan_to_previous_word_end(tb.line_graphemes(y), int(x), int(y), int(src_y)) {
			tb.move_cursor_to_position(u64(pos.y), u64(pos.x))
			return
		}
		if y == 0 {
			return
		}
		y -= 1
		prev_graphemes := tb.line_graphemes(y)
		x = if prev_graphemes.len == 0 { u64(0) } else { u64(prev_graphemes.len - 1) }
	}
}

pub fn (mut tb TextBuffer) move_cursor_to_next_big_word_start() {
	src_y, start_x := tb.cursor_line_and_x()
	line_count := tb.line_buf.len()
	mut y := src_y
	mut x := start_x
	for {
		if pos := scan_to_next_big_word_start(tb.line_graphemes(y), int(x), int(y), int(src_y)) {
			tb.move_cursor_to_position(u64(pos.y), u64(pos.x))
			return
		}
		next_y := y + 1
		if next_y >= u64(line_count) {
			return
		}
		y = next_y
		x = 0
	}
}

struct MotionPos {
	x int
	y int
}

fn scan_to_next_word_start(graphemes []string, px int, py int, source_y int) ?MotionPos {
	if py != source_y && px == 0 {
		if graphemes.len == 0 {
			return MotionPos{x: px, y: py}
		}
		if grapheme_char_type(graphemes[px]) != .whitespace {
			return MotionPos{x: px, y: py}
		}
	}

	mut c_scanner := CharScanner{
		last_index: px
		data:       graphemes
	}
	diff := c_scanner.next_diff() or { return none }

	if diff.next_type == .whitespace {
		post := c_scanner.next_diff() or { return none }
		return MotionPos{x: post.index, y: py}
	}
	return MotionPos{x: diff.index, y: py}
}

fn scan_to_previous_word_start(graphemes []string, px int, py int, source_y int) ?MotionPos {
	if py != source_y {
		if graphemes.len == 0 {
			return MotionPos{x: px, y: py}
		}
		if px == 0 {
			if grapheme_char_type(graphemes[px]) != .whitespace {
				return MotionPos{x: px, y: py}
			}
		} else {
			c_type := grapheme_char_type(graphemes[px])
			if c_type != .whitespace {
				mut word_start := px
				for i := px - 1; i >= 0; i-- {
					if grapheme_char_type(graphemes[i]) != c_type {
						break
					}
					word_start = i
				}
				return MotionPos{x: word_start, y: py}
			}
		}
	}

	mut c_scanner := CharScanner{
		last_index: px
		data:       graphemes
	}
	diff := c_scanner.prev_diff() or { return none }

	if diff.start_type == .alpha_num || diff.start_type == .other {
		if pre := diff.pre_diff {
			return MotionPos{x: pre.index, y: py}
		}
		if diff.next_type == .whitespace {
			c_scanner.prev_diff() or { return none }
			return find_prev_token_start(mut c_scanner, py)
		}
		return find_prev_token_start(mut c_scanner, py)
	}

	if diff.start_type == .whitespace {
		return find_prev_token_start(mut c_scanner, py)
	}

	return MotionPos{x: px, y: py}
}

fn find_prev_token_start(mut c_scanner CharScanner, y int) ?MotionPos {
	diff := c_scanner.prev_diff() or { return MotionPos{x: 0, y: y} }
	if pre := diff.pre_diff {
		return MotionPos{x: pre.index, y: y}
	}
	return MotionPos{x: diff.index + 1, y: y}
}

fn scan_to_next_word_end(graphemes []string, px int, py int, source_y int) ?MotionPos {
	if py != source_y && px == 0 {
		if graphemes.len == 0 {
			return MotionPos{x: px, y: py}
		}
	}

	start := if py == source_y { px + 1 } else { px }
	if start >= graphemes.len {
		return none
	}

	mut x := start
	for x < graphemes.len && grapheme_char_type(graphemes[x]) == .whitespace {
		x++
	}
	if x >= graphemes.len {
		return none
	}

	word_class := grapheme_char_type(graphemes[x])
	for x + 1 < graphemes.len && grapheme_char_type(graphemes[x + 1]) == word_class {
		x++
	}

	return MotionPos{x: x, y: py}
}

fn scan_to_previous_word_end(graphemes []string, px int, py int, source_y int) ?MotionPos {
	if py != source_y {
		if graphemes.len == 0 {
			return MotionPos{x: px, y: py}
		}
		mut x := graphemes.len - 1
		for x >= 0 && grapheme_char_type(graphemes[x]) == .whitespace {
			x--
		}
		if x < 0 {
			return none
		}
		return MotionPos{x: x, y: py}
	}

	if px <= 0 {
		return none
	}

	mut x := px - 1
	curr_class := grapheme_char_type(graphemes[x])

	if curr_class == .whitespace {
		for x >= 0 && grapheme_char_type(graphemes[x]) == .whitespace {
			x--
		}
		if x < 0 {
			return none
		}
		return MotionPos{x: x, y: py}
	}

	orig_class := grapheme_char_type(graphemes[px])
	if curr_class != orig_class {
		return MotionPos{x: x, y: py}
	}

	for x >= 0 && grapheme_char_type(graphemes[x]) == curr_class {
		x--
	}
	if x < 0 {
		return none
	}

	if grapheme_char_type(graphemes[x]) == .whitespace {
		for x >= 0 && grapheme_char_type(graphemes[x]) == .whitespace {
			x--
		}
		if x < 0 {
			return none
		}
	}

	return MotionPos{x: x, y: py}
}

fn scan_to_next_big_word_start(graphemes []string, px int, py int, source_y int) ?MotionPos {
	if py != source_y && px == 0 {
		if graphemes.len == 0 {
			return MotionPos{x: px, y: py}
		}
		if !grapheme_is_space(graphemes[px]) {
			return MotionPos{x: px, y: py}
		}
	}

	mut x := px
	for x < graphemes.len && !grapheme_is_space(graphemes[x]) {
		x++
	}
	for x < graphemes.len && grapheme_is_space(graphemes[x]) {
		x++
	}

	if x >= graphemes.len {
		return none
	}
	return MotionPos{x: x, y: py}
}

struct CharScanner {
	data []string
mut:
	last_index int
}

struct ScanResult {
	index      int
	pre_diff   ?PreDiffChar
	start_type CharType
	next_type  CharType
}

struct PreDiffChar {
	index  int
	c_type CharType
}

fn (mut s CharScanner) prev_diff() ?ScanResult {
	if s.data.len == 0 || s.last_index <= 0 {
		return none
	}
	if s.last_index >= s.data.len {
		s.last_index = s.data.len - 1
	}
	start_type := grapheme_char_type(s.data[s.last_index])
	for i := s.last_index; i >= 0; i-- {
		c_type := grapheme_char_type(s.data[i])
		pre_diff_char := ?PreDiffChar(if i + 1 < s.last_index {
			PreDiffChar{
				index:  i + 1
				c_type: grapheme_char_type(s.data[i + 1])
			}
		} else {
			none
		})

		if c_type != start_type {
			s.last_index = i
			return ScanResult{
				index:      i
				pre_diff:   pre_diff_char
				start_type: start_type
				next_type:  c_type
			}
		}
	}
	return none
}

fn (mut s CharScanner) next_diff() ?ScanResult {
	if s.data.len == 0 || s.last_index >= s.data.len {
		return none
	}
	start_type := grapheme_char_type(s.data[s.last_index])
	for i := s.last_index; i < s.data.len; i++ {
		c_type := grapheme_char_type(s.data[i])
		if c_type != start_type {
			s.last_index = i
			return ScanResult{
				index:      i
				start_type: start_type
				next_type:  c_type
			}
		}
	}
	return none
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


