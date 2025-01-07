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

pub fn (mut gap_buffer GapBuffer) backspace() bool {
	if gap_buffer.gap_start == 0 { return false }
	gap_buffer.gap_start -= 1
	return gap_buffer.data[gap_buffer.gap_start] == lf
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

fn resolve_cursor_pos(mut scanner Scanner, data []rune, offset int, gap_start int, gap_end int) ?Pos {
	mut gap_count := 0
	for index, c in data[offset..] {
		cc := (index + offset)
		if cc > gap_start && cc < gap_end {
			gap_count += 1
			continue
		}
		scanner.consume(index - gap_count, c)
		if scanner.done() {
			return scanner.result()
		}
	}

	return none
}

pub fn (gap_buffer GapBuffer) find_next_word_start(pos Pos) ?Pos {
	mut cursor_loc := pos
	mut offset := gap_buffer.find_offset(cursor_loc) or { return none }

	mut scanner := WordStartScanner{
		start_pos: cursor_loc
	}

	return resolve_cursor_pos(mut scanner, gap_buffer.data, offset, gap_buffer.gap_start, gap_buffer.gap_end)
}

pub fn (gap_buffer GapBuffer) find_next_word_end(pos Pos) ?Pos {
	mut cursor_loc := pos
	mut offset := gap_buffer.find_offset(cursor_loc) or { return none }

	mut scanner := WordEndScanner{
		start_pos: cursor_loc
	}

	return resolve_cursor_pos(mut scanner, gap_buffer.data, offset, gap_buffer.gap_start, gap_buffer.gap_end)
}

pub fn (gap_buffer GapBuffer) find_prev_word_start(pos Pos) ?Pos {
	mut cursor_loc := pos
	mut offset := gap_buffer.find_offset(cursor_loc) or { return none }

	if offset > gap_buffer.gap_end {
		offset -= gap_buffer.gap_end - gap_buffer.gap_start
	}

	data_pre_gap := gap_buffer.data[..gap_buffer.gap_start]
	data_post_gap := gap_buffer.data[gap_buffer.gap_end..]

	mut previous_cchar := rune(-1)
	mut data := arrays.merge(data_pre_gap, data_post_gap)[..offset]
	for i := data.len - 1; i >= 0; i-- {
		iter_count := data.len - 1 - i
		cchar := data[i]
		if iter_count >= 1 { previous_cchar = data[i + 1] }

		if is_whitespace(cchar) && cchar != lf {
			if iter_count >= 1 && !is_whitespace(previous_cchar) {
				break
			}
			cursor_loc.x -= 1
			continue
		}

		if cchar == lf {
			cursor_loc.y -= 1
			mut line_len := 0
			for j := i; j >= 0; j-- {
				if i == j { continue }
				if data[j] == lf {
					line_len = i - j
					break
				}
				if j == 0 {
					line_len = i
					break
				}
			}
			cursor_loc.x = line_len
			if cursor_loc.x == 0 {
				break
			}
			continue
		}

		if !is_whitespace(cchar) {
			cursor_loc.x -= 1
			continue
		}
	}

	return cursor_loc
}

pub fn (gap_buffer GapBuffer) left(pos Pos) ?Pos {
	mut cursor_loc := pos
	mut offset := gap_buffer.find_offset(cursor_loc) or { return none }

	if offset > gap_buffer.gap_end {
		offset -= gap_buffer.gap_end - gap_buffer.gap_start
	}

	// 07/01/25 FIX(tauraamui): this is unacceptable for just moving the cursor
	//                          one position left or right, however its the fastest
	//                          method to implement for now, but this needs to be
	//                          optimised
	data_pre_gap := gap_buffer.data[..gap_buffer.gap_start]
	data_post_gap := gap_buffer.data[gap_buffer.gap_end..]
	data := arrays.merge(data_pre_gap, data_post_gap)

	if data.len == 0 { return none }
	if offset - 1 < 0 { return none }

	if data[offset - 1] == lf {
		cursor_loc.x = 0
		cursor_loc.y -= 1
		return cursor_loc
	}

	cursor_loc.x -= 1

	return cursor_loc
}

pub fn (gap_buffer GapBuffer) right(pos Pos) ?Pos {
	mut cursor_loc := pos
	mut offset := gap_buffer.find_offset(cursor_loc) or { return none }

	if offset > gap_buffer.gap_end {
		offset -= gap_buffer.gap_end - gap_buffer.gap_start
	}

	// 07/01/25 FIX(tauraamui): this is unacceptable for just moving the cursor
	//                          one position left or right, however its the fastest
	//                          method to implement for now, but this needs to be
	//                          optimised
	data_pre_gap := gap_buffer.data[..gap_buffer.gap_start]
	data_post_gap := gap_buffer.data[gap_buffer.gap_end..]
	data := arrays.merge(data_pre_gap, data_post_gap)

	if data.len == 0 { return none }
	if offset + 1 >= data.len { return none }

	if data[offset + 1] == lf {
		cursor_loc.x = 0
		cursor_loc.y += 1
		return cursor_loc
	}

	cursor_loc.x += 1

	return cursor_loc
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

interface Scanner {
mut:
	consume(index int, c rune)
	done() bool
	result() Pos
}

struct WordStartScanner {
mut:
	start_pos  Pos
	compound_x int
	compound_y int
	previous   rune
	set_previous bool
	set_x_to_line_end bool
	done       bool
	res        ?Pos
}

fn (mut s WordStartScanner) consume(index int, c rune) {
	defer { s.previous = c }

	if !is_whitespace(c) {
		if is_whitespace(s.previous) {
			s.done = true
			return
		}
		s.compound_x += 1
	}

	if is_whitespace(c) {
		s.compound_x += 1
		if c == lf {
			s.compound_x = 0
			s.start_pos.x = 0
			if s.previous == lf {
				s.done = true
				return
			}
			s.compound_y += 1
		}
		return
	}
}

fn (s WordStartScanner) done() bool {
	return s.done
}

fn (mut s WordStartScanner) result() Pos {
	return Pos{ x: s.start_pos.x + s.compound_x, y: s.start_pos.y + s.compound_y }
}

struct ReverseWordStartScanner {
mut:
	start_pos  Pos
	compound_x int
	compound_y int
	previous rune
	set_previous bool
	non_whitespace_count int
	done     bool
}

fn (mut s ReverseWordStartScanner) consume(index int, c rune, line_len int, short_circuited bool) bool {
	defer {
		s.previous = c
		s.set_previous = true
	}

	if s.set_previous && s.previous == lf {
		if line_len == 0 {
			s.done = true
			return false
		}
		s.compound_x = 0
		s.start_pos.x = line_len
	}

	if c == lf {
		if !short_circuited {
			s.compound_y += 1
		}
		s.compound_x = 0
		return true
	}

	if is_whitespace(c) {
		if s.set_previous && !is_whitespace(s.previous) {
			s.compound_x -= 1
			s.done = true
			return false
		}
		s.compound_x += 1
	}

	if !is_whitespace(c) {
		s.compound_x += 1
	}

	return false
}

fn (s ReverseWordStartScanner) done() bool {
	return s.done
}

fn (mut s ReverseWordStartScanner) result() Pos {
	defer {
		s.compound_x = 0
		s.compound_y = 0
	}
	return Pos{ x: s.start_pos.x - s.compound_x, y: s.start_pos.y - s.compound_y }
}

struct WordEndScanner {
mut:
	start_pos  Pos
	compound_x int
	compound_y int
	previous   rune
	done       bool
	res        ?Pos
}

fn (mut s WordEndScanner) consume(index int, c rune) {
	defer { s.previous = c }

	if is_whitespace(c) && !is_whitespace(s.previous) && index > 1 {
		s.done = true
		s.compound_x -= 1
		return
	}

	if is_whitespace(c) {
		s.compound_x += 1
		if c == lf {
			s.compound_x = 0
			s.start_pos.x = 0
			if s.previous == lf {
				s.done = true
				return
			}
			s.compound_y += 1
		}
		return
	}

	s.compound_x += 1
}

fn (mut s WordEndScanner) done() bool {
	return s.done
}

fn (mut s WordEndScanner) result() Pos {
	return Pos{ x: s.start_pos.x + s.compound_x, y: s.start_pos.y + s.compound_y }
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
	return r == ` ` || r == `\t` || r == lf || r == `\r`
}

fn is_alpha_underscore(r int) bool {
	return is_alpha(u8(r)) || u8(r) == `_` || u8(r) == `#` || u8(r) == `$`
}
