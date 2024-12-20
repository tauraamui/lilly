module buffer

import strings
import arrays

const gap_size = 32

struct LineTracker {
	line_starts []int
	gap_start   int
	gap_end     int
}

struct GapBuffer {
mut:
	data      []rune
	gap_start int
	gap_end   int
}

fn GapBuffer.new(d string) GapBuffer {
	mut gb := GapBuffer{
		data:      d.runes()
		gap_start: 0
		gap_end:   0
	}
	gb.resize_if_full()
	return gb
}

pub fn (mut gap_buffer GapBuffer) move_cursor_to(pos Pos) {
	gap_sizee := gap_buffer.gap_end - gap_buffer.gap_start
	offset := gap_buffer.find_offset(pos) or { return }
	gap_buffer.move_cursor(offset - gap_sizee)
}

pub fn (mut gap_buffer GapBuffer) insert(r rune) {
	gap_buffer.insert_rune(r)
}

pub fn (mut gap_buffer GapBuffer) insert_at(r rune, pos Pos) {
	gap_buffer.move_cursor_to(pos)
	gap_buffer.insert_rune(r)
}

pub fn (mut gap_buffer GapBuffer) backspace() {
	if gap_buffer.gap_start == 0 { return }
	gap_buffer.gap_start -= 1
}

pub fn (mut gap_buffer GapBuffer) delete(ignore_newlines bool) {
	if ignore_newlines && gap_buffer.gap_end < gap_buffer.data.len && gap_buffer.data[gap_buffer.gap_end] == lf { return }
	if gap_buffer.gap_end + 1 == gap_buffer.data.len { return }
	gap_buffer.gap_end += 1
}

fn (mut gap_buffer GapBuffer) insert_rune(r rune) {
	gap_buffer.data[gap_buffer.gap_start] = r
	gap_buffer.gap_start += 1
	gap_buffer.resize_if_full()
}

fn (mut gap_buffer GapBuffer) move_cursor(offset int) {
	if offset < gap_buffer.gap_start {
		gap_buffer.move_cursor_left(gap_buffer.gap_start - offset)
		return
	}

	if offset > gap_buffer.gap_start {
		gap_buffer.move_cursor_right(offset - gap_buffer.gap_start)
		return
	}
}

fn (mut gap_buffer GapBuffer) move_cursor_left(count int) {
	max_allowed_count := gap_buffer.gap_start
	to_move_count := int_min(count, max_allowed_count)

	for _ in 0..to_move_count {
		gap_buffer.data[gap_buffer.gap_end - 1] = gap_buffer.data[gap_buffer.gap_start - 1]
		gap_buffer.gap_start -= 1
		gap_buffer.gap_end   -= 1
	}
}

fn (mut gap_buffer GapBuffer) move_cursor_right(count int) {
	max_allowed_count := gap_buffer.data.len - gap_buffer.gap_end
	to_move_count := int_min(count, max_allowed_count)

	for _ in 0..to_move_count {
		gap_buffer.data[gap_buffer.gap_start] = gap_buffer.data[gap_buffer.gap_end]
		gap_buffer.gap_start += 1
		gap_buffer.gap_end   += 1
	}
}

fn (mut gap_buffer GapBuffer) resize_if_full() {
	if gap_buffer.empty_gap_space_size() != 0 { return }
	size := gap_buffer.data.len + gap_size
	mut data_dest := []rune{ len: size, cap: size }

	arrays.copy(mut data_dest[..gap_buffer.gap_start], gap_buffer.data[..gap_buffer.gap_start])
	arrays.copy(mut data_dest[gap_buffer.gap_end + (gap_size - (gap_buffer.empty_gap_space_size()))..], gap_buffer.data[gap_buffer.gap_end..])
	gap_buffer.gap_end += gap_size

	gap_buffer.data = data_dest
}

pub fn (gap_buffer GapBuffer) in_bounds(pos Pos) bool {
	_ := gap_buffer.find_offset(pos) or { return false }
	return true
}

pub fn (gap_buffer GapBuffer) find_end_of_line(pos Pos) ?int {
	offset := gap_buffer.find_offset(pos) or { return none }

	for count, r in gap_buffer.data[offset..] {
		cc := (count + offset)
		if cc > gap_buffer.gap_start && cc < gap_buffer.gap_end { continue }
		if r == lf { return count }
	}

	return gap_buffer.data[offset..].len
}

pub fn (gap_buffer GapBuffer) find_next_word_start(pos Pos) Pos {
	offset := gap_buffer.find_offset(pos) or { return pos }

	started_within_current_word := !is_whitespace(gap_buffer.data[offset])
	next_char_offset            := gap_buffer.find_offset(Pos{ x: pos.x + 1, y: pos.y }) or { -1 }
	started_at_word_end         := next_char_offset >= 0 && is_whitespace(gap_buffer.data[next_char_offset])
	mut elapsed_line            := false

	for count, r in gap_buffer.data[offset..] {
		cc := (count + offset)
		if cc > gap_buffer.gap_start && cc < gap_buffer.gap_end { continue }
	}

	mut found_word_end := false
	mut new_pos := Pos{ x: pos.x, y: pos.y }
	for count, r in gap_buffer.data[offset..] {

		if r == lf {
			new_pos.x = 0
			new_pos.y += 1
			elapsed_line = true
			continue
		}

		if elapsed_line {
			if !is_whitespace(r) {
				break
			}
		}

		if started_within_current_word && !started_at_word_end {
			if !found_word_end {
				found_word_end = is_whitespace(r)
			}
			if found_word_end {
				if !is_whitespace(r) {
					break
				}
			}
		}

		new_pos.x += 1
	}
	return new_pos
}

// FIXME(tauraamui): I think this function doesn't need to include the gap as part of the offset'
fn (gap_buffer GapBuffer) find_offset(pos Pos) ?int {
	pre_gap_data := gap_buffer.data[..gap_buffer.gap_start]

	mut line := 0
	mut line_offset := 0

	for offset, c in pre_gap_data {
		if line == pos.y && line_offset == pos.x {
			return offset
		}

		if c == lf {
			line += 1
			line_offset = 0
			continue
		}

		line_offset += 1
	}

	if line == pos.y && line_offset == pos.x {
		return gap_buffer.gap_start + (gap_buffer.gap_end - gap_buffer.gap_start)
	}

	post_gap_data := gap_buffer.data[gap_buffer.gap_start + (gap_buffer.gap_end - gap_buffer.gap_start)..]
	for offset, c in post_gap_data {
		if line == pos.y && line_offset == pos.x {
			return gap_buffer.gap_start + (gap_buffer.gap_end - gap_buffer.gap_start) + offset
		}

		if c == lf {
			line += 1
			line_offset = 0
			continue
		}

		line_offset += 1
	}

	if line == pos.y && line_offset == pos.x {
		return gap_buffer.data.len
	}

	return none
}

@[inline]
fn (gap_buffer GapBuffer) empty_gap_space_size() int {
	return gap_buffer.gap_end - gap_buffer.gap_start
}

@[inline]
fn (gap_buffer GapBuffer) str() string {
	return gap_buffer.data[..gap_buffer.gap_start].string() + gap_buffer.data[gap_buffer.gap_end..].string()
}

fn (gap_buffer GapBuffer) raw_str() string {
	mut sb := strings.new_builder(512)
	sb.write_runes(gap_buffer.data[..gap_buffer.gap_start])
	sb.write_string(strings.repeat_string("_", gap_buffer.gap_end - gap_buffer.gap_start))
	sb.write_runes(gap_buffer.data[gap_buffer.gap_end..])
	return sb.str()
}

pub const lf := `\n`

struct GapBufferIterator {
	data  string
mut:
	line_start int
	done       bool
}

fn new_gap_buffer_iterator(buffer GapBuffer) GapBufferIterator {
	return GapBufferIterator{
		data: buffer.str()
	}
}

pub fn (mut iter GapBufferIterator) next() ?string {
	if iter.done { return none }
	mut line := ?string(none)
	for index in iter.line_start..iter.data.len {
		if iter.data[index] == lf {
			line = iter.data[iter.line_start..index]
			iter.line_start = index + 1
			break
		}

		if index + 1 == iter.data.len {
			iter.done = true
			line = iter.data[iter.line_start..]
			break
		}
	}

	return line
}

fn is_non_alpha(c rune) bool {
	return c != `_` && !is_alpha(c)
}

fn is_alpha(r rune) bool {
	return (r >= `a` && r <= `z`) || (r >= `A` && r <= `Z`) || (r >= `0` && r <= `9`)
}

fn is_whitespace(r rune) bool {
	return r == ` ` || r == `\t` || r == `\n` || r == `\r`
}

fn is_alpha_underscore(r int) bool {
	return is_alpha(u8(r)) || u8(r) == `_` || u8(r) == `#` || u8(r) == `$`
}
