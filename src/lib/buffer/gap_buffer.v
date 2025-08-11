// Copyright 2024 The Lilly Editor contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

module buffer

import strings
import arrays
import lib.search

pub const gap_size = 32

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

pub fn (gap_buffer GapBuffer) read(range Range) ?string {
	start_offset := gap_buffer.find_offset(range.start) or { return none }
	end_offset := gap_buffer.find_offset(range.end) or { return none }

	if start_offset < gap_buffer.gap_start && gap_buffer.gap_start < end_offset {
		gap_size := gap_buffer.gap_end - gap_buffer.gap_start
		first_half := gap_buffer.data[start_offset..gap_buffer.gap_start]
		second_half := gap_buffer.data[gap_buffer.gap_start + gap_size..end_offset]

		return arrays.merge(first_half, second_half).string()
	}

	return gap_buffer.data[start_offset..end_offset].string()
}

pub fn (mut gap_buffer GapBuffer) move_cursor_to(pos Position) {
	gap_sizee := gap_buffer.gap_end - gap_buffer.gap_start
	offset := gap_buffer.find_offset(pos) or { return }
	gap_buffer.move_data_cursor(offset - gap_sizee)
}

// TODO(tauraamui) [01/07/2025]: refactor all of the public methods for inserting
//                               text content to bring it down to one entrypoint
pub fn (mut gap_buffer GapBuffer) insert(r rune) {
	gap_buffer.insert_rune(r)
}

pub fn (mut gap_buffer GapBuffer) insert_at(r rune, pos Position) {
	gap_buffer.move_cursor_to(pos)
	gap_buffer.insert_rune(r)
}

pub fn (mut gap_buffer GapBuffer) backspace() bool {
	if gap_buffer.gap_start == 0 {
		return false
	}
	gap_buffer.gap_start -= 1
	return gap_buffer.data[gap_buffer.gap_start] == lf
}

// delete removes rune at current pos, returns true if a line has been fully deleted
// and the source cursor's y needs to be decremented
pub fn (mut gap_buffer GapBuffer) delete(ignore_newlines bool) bool {
	if ignore_newlines && gap_buffer.gap_end < gap_buffer.data.len
		&& gap_buffer.data[gap_buffer.gap_end] == lf {
		return false
	}
	if gap_buffer.gap_end + 1 == gap_buffer.data.len {
		return false
	}
	gap_buffer.gap_end += 1
	return true
}

pub fn (mut gap_buffer GapBuffer) x(pos Pos) ?Pos {
	gap_buffer.move_cursor_to(Position.new(line: pos.y, offset: pos.x))
	distance_to_end_of_line := gap_buffer.find_end_of_line(pos) or { 0 }
	if distance_to_end_of_line == 0 {
		return none
	}
	gap_buffer.gap_end += 1
	return pos
}

pub fn (mut gap_buffer GapBuffer) o(pos Position) ?Position {
	end_of_line_pos := gap_buffer.find_end_of_line2(pos)?
	gap_buffer.insert_at(lf, end_of_line_pos)
	return Position.new(line: end_of_line_pos.line, offset: 0).add(Distance{ lines: 1 })
}

fn (mut gap_buffer GapBuffer) insert_rune(r rune) {
	gap_buffer.data[gap_buffer.gap_start] = r
	gap_buffer.gap_start += 1
	gap_buffer.resize_if_full()
}

fn (mut gap_buffer GapBuffer) move_data_cursor(offset int) {
	if offset < gap_buffer.gap_start {
		gap_buffer.move_data_cursor_left(gap_buffer.gap_start - offset)
		return
	}

	if offset > gap_buffer.gap_start {
		gap_buffer.move_data_cursor_right(offset - gap_buffer.gap_start)
		return
	}
}

fn (mut gap_buffer GapBuffer) move_data_cursor_left(count int) {
	max_allowed_count := gap_buffer.gap_start
	to_move_count := int_min(count, max_allowed_count)

	for _ in 0 .. to_move_count {
		gap_buffer.data[gap_buffer.gap_end - 1] = gap_buffer.data[gap_buffer.gap_start - 1]
		gap_buffer.gap_start -= 1
		gap_buffer.gap_end -= 1
	}
}

fn (mut gap_buffer GapBuffer) move_data_cursor_right(count int) {
	max_allowed_count := gap_buffer.data.len - gap_buffer.gap_end
	to_move_count := int_min(count, max_allowed_count)

	for _ in 0 .. to_move_count {
		gap_buffer.data[gap_buffer.gap_start] = gap_buffer.data[gap_buffer.gap_end]
		gap_buffer.gap_start += 1
		gap_buffer.gap_end += 1
	}
}

fn (mut gap_buffer GapBuffer) resize_if_full() {
	if gap_buffer.empty_gap_space_size() != 0 {
		return
	}
	size := gap_buffer.data.len + gap_size
	mut data_dest := []rune{len: size, cap: size}

	arrays.copy(mut data_dest[..gap_buffer.gap_start], gap_buffer.data[..gap_buffer.gap_start])
	arrays.copy(mut data_dest[gap_buffer.gap_end + (gap_size - (gap_buffer.empty_gap_space_size()))..],
		gap_buffer.data[gap_buffer.gap_end..])
	gap_buffer.gap_end += gap_size

	gap_buffer.data = data_dest
}

pub fn (gap_buffer GapBuffer) in_bounds(pos Pos) bool {
	_ := gap_buffer.find_offset(Position.new(line: pos.y, offset: pos.x)) or { return false }
	return true
}

// NOTE(tauraamui) [15/07/2025]: keep this around until we get around to migrating all of the buffer types
//                               to use the new Position type
// GapBuffer.find_end_of_line2 returns a position with line and offset data to represent the end position
// of the starting line.
pub fn (gap_buffer GapBuffer) find_end_of_line2(pos Position) ?Position {
	offset := gap_buffer.find_offset(pos) or { return none }

	for count, r in gap_buffer.data[offset..] {
		cc := (count + offset)
		if cc > gap_buffer.gap_start && cc < gap_buffer.gap_end {
			continue
		}
		if r == lf {
			return pos.add(Distance{ offset: count })
		}
	}

	return pos.add(Distance{ offset: gap_buffer.data[offset..].len })
}

// GapBuffer.find_end_of_line returns the distance between the current position's offset
// and the end of the line.
pub fn (gap_buffer GapBuffer) find_end_of_line(pos Pos) ?int {
	cursor_loc := pos
	offset := gap_buffer.find_offset(Position.new(line: cursor_loc.y, offset: cursor_loc.x)) or {
		return none
	}

	for count, r in gap_buffer.data[offset..] {
		cc := (count + offset)
		if cc > gap_buffer.gap_start && cc < gap_buffer.gap_end {
			continue
		}
		if r == lf {
			return count
		}
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
	return gap_buffer.find_next_word_start_old(pos)
}

pub fn (gap_buffer GapBuffer) find_next_word_start_new(pos Position) ?Position {
	mut offset := gap_buffer.find_offset(pos) or { return none }

	mut scanner := WordStartScanner{
		start_pos: position_to_pos(pos)
	}

	return if resolved_pos := resolve_cursor_pos(mut scanner, gap_buffer.data, offset,
		gap_buffer.gap_start, gap_buffer.gap_end)
	{
		pos_to_position(resolved_pos)
	} else {
		none
	}
}

pub fn (gap_buffer GapBuffer) find_next_word_start_old(pos Pos) ?Pos {
	mut cursor_loc := pos
	mut offset := gap_buffer.find_offset(Position.new(line: cursor_loc.y, offset: cursor_loc.x)) or {
		return none
	}

	mut scanner := WordStartScanner{
		start_pos: cursor_loc
	}

	return resolve_cursor_pos(mut scanner, gap_buffer.data, offset, gap_buffer.gap_start,
		gap_buffer.gap_end)
}

pub fn (gap_buffer GapBuffer) find_next_word_end(pos Pos) ?Pos {
	mut cursor_loc := pos
	mut offset := gap_buffer.find_offset(Position.new(line: cursor_loc.y, offset: cursor_loc.x)) or {
		return none
	}

	mut scanner := WordEndScanner{
		start_pos: cursor_loc
	}

	return resolve_cursor_pos(mut scanner, gap_buffer.data, offset, gap_buffer.gap_start,
		gap_buffer.gap_end)
}

pub fn (gap_buffer GapBuffer) find_prev_word_start(pos Pos) ?Pos {
	mut cursor_loc := pos
	mut offset := gap_buffer.find_offset(Position.new(line: cursor_loc.y, offset: cursor_loc.x)) or {
		return none
	}

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
		if iter_count >= 1 {
			previous_cchar = data[i + 1]
		}

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
				if i == j {
					continue
				}
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

// TODO(tauraamui) [20/01/25]: Need to adjust movement behaviour based on mode,
//                             so basically when we're in insert mode do the thing.
pub fn (gap_buffer GapBuffer) left(pos Pos) ?Pos {
	mut cursor_loc := pos
	mut offset := gap_buffer.find_offset(Position.new(line: cursor_loc.y, offset: cursor_loc.x)) or {
		return none
	}

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
	//

	if data.len == 0 {
		return none
	}
	if cursor_loc.x - 1 < 0 {
		return none
	}

	if data[cursor_loc.x - 1] == lf {
		return none
	}

	cursor_loc.x -= 1
	if cursor_loc.x < 0 {
		cursor_loc.x = 0
	}

	return cursor_loc
}

pub fn (gap_buffer GapBuffer) right(pos Pos, insert_mode bool) ?Pos {
	mut cursor_loc := pos
	mut offset := gap_buffer.find_offset(Position.new(line: cursor_loc.y, offset: cursor_loc.x)) or {
		return none
	}

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
	//

	if data.len == 0 {
		return none
	}
	if cursor_loc.x + 1 >= data.len {
		return none
	}

	if data[cursor_loc.x + 1] == lf {
		return none
	}

	cursor_loc.x += 1

	return cursor_loc
}

pub fn (gap_buffer GapBuffer) down(pos Pos) ?Pos {
	mut cursor_loc := pos
	mut offset := gap_buffer.find_offset(Position.new(line: cursor_loc.y, offset: cursor_loc.x)) or {
		return none
	}

	if offset > gap_buffer.gap_end {
		offset -= gap_buffer.gap_end - gap_buffer.gap_start
	}

	// FIX(tauraamui) [07/01/25]: this is unacceptable for just moving the cursor
	//                          one position up or down, however its the fastest
	//                          method to implement for now, but this needs to be
	//                          optimised
	data_pre_gap := gap_buffer.data[..gap_buffer.gap_start]
	data_post_gap := gap_buffer.data[gap_buffer.gap_end..]
	data := arrays.merge(data_pre_gap, data_post_gap)[offset..]
	//

	if data.len == 0 {
		return none
	}

	mut already_found_newline := false
	for cchar in data {
		if cchar == lf {
			if already_found_newline {
				break
			}
			already_found_newline = true
			cursor_loc.y += 1
			cursor_loc.x = -1
			continue
		}
		if already_found_newline {
			cursor_loc.x += 1
			if cursor_loc.x > pos.x {
				cursor_loc.x = pos.x
				break
			}
		}
	}

	if cursor_loc.x < 0 {
		cursor_loc.x = 0
	}

	return cursor_loc
}

pub fn (gap_buffer GapBuffer) up(pos Pos) ?Pos {
	mut cursor_loc := pos
	mut offset := gap_buffer.find_offset(Position.new(line: cursor_loc.y, offset: cursor_loc.x)) or {
		return none
	}

	if offset > gap_buffer.gap_end {
		offset -= gap_buffer.gap_end - gap_buffer.gap_start
	}

	// FIX(tauraamui) [07/01/25]: this is unacceptable for just moving the cursor
	//                          one position left or right, however its the fastest
	//                          method to implement for now, but this needs to be
	//                          optimised
	data_pre_gap := gap_buffer.data[..gap_buffer.gap_start]
	data_post_gap := gap_buffer.data[gap_buffer.gap_end..]
	data := arrays.merge(data_pre_gap, data_post_gap)
	//

	if data.len == 0 {
		return none
	}

	mut already_found_newline := false
	for cchar in data {
		if cchar == lf {
			if already_found_newline {
				break
			}
			already_found_newline = true
			cursor_loc.y -= 1
			cursor_loc.x = -1
			continue
		}
		if already_found_newline {
			cursor_loc.x += 1
			if cursor_loc.x > pos.x {
				cursor_loc.x = pos.x
				break
			}
		}
	}

	if cursor_loc.x < 0 {
		cursor_loc.x = 0
	}

	return cursor_loc
}

// up_to_next_blank_line returns cursor position at start of next blank line above current cursor.
// If no blank line is found above the given cursor position `none` is returned instead.
pub fn (gap_buffer GapBuffer) up_to_next_blank_line(pos Pos) ?Pos {
	mut cursor_loc := pos
	cursor_loc.x = 0
	mut offset := gap_buffer.find_offset(Position.new(line: cursor_loc.y, offset: cursor_loc.x)) or {
		return none
	}
	offset -= gap_buffer.empty_gap_space_size()

	// NOTE(tauraamui) [10/01/25]:
	// this copying of the two sides of the buffer might be worth
	// it for this kind of long distance movement of the cursor
	// but I would still much prefer iteration that can ignore the
	// gap without making the maths all wacky for tracking how far
	// we've actually elapsed in the data as opposed to how much
	// was the gap size. Should probably benchmark and alloc profile
	// the two different options.
	data_pre_gap := gap_buffer.data[..gap_buffer.gap_start]
	data_post_gap := gap_buffer.data[gap_buffer.gap_end..]
	data := arrays.merge(data_pre_gap, data_post_gap)

	mut newline_count := 0
	mut last_rune_was_newline := false
	for i := offset; i >= 0; i-- {
		c := data[i]
		// we may have started on an existing blank line,
		// so the first newline encountered should be ignored
		if i != offset && c == lf {
			if last_rune_was_newline {
				cursor_loc.y -= newline_count
				return cursor_loc
			}
			newline_count += 1
			last_rune_was_newline = true
			continue
		}
		last_rune_was_newline = false
	}

	return none
}

pub fn (gap_buffer GapBuffer) down_to_next_blank_line(pos Pos) ?Pos {
	mut cursor_loc := pos
	mut offset := gap_buffer.find_offset(Position.new(line: cursor_loc.y, offset: cursor_loc.x)) or {
		return none
	}

	if offset > gap_buffer.gap_end {
		offset -= gap_buffer.empty_gap_space_size()
	}

	// NOTE(tauraamui) [10/01/25]:
	// this copying of the two sides of the buffer might be worth
	// it for this kind of long distance movement of the cursor
	// but I would still much prefer iteration that can ignore the
	// gap without making the maths all wacky for tracking how far
	// we've actually elapsed in the data as opposed to how much
	// was the gap size. Should probably benchmark and alloc profile
	// the two different options.
	data_pre_gap := gap_buffer.data[..gap_buffer.gap_start]
	data_post_gap := gap_buffer.data[gap_buffer.gap_end..]
	data := arrays.merge(data_pre_gap, data_post_gap)

	mut compound_y := 0
	for i in offset .. data.len - 1 {
		if data[i] == lf {
			compound_y += 1
			if i + 1 <= data.len - 1 {
				if data[i + 1] == lf {
					break
				}
			}
		}
	}

	if compound_y > 0 {
		cursor_loc.x = 0
		cursor_loc.y += compound_y
	}

	return cursor_loc
}

@[inline]
fn (gap_buffer GapBuffer) empty_gap_space_size() int {
	return gap_buffer.gap_end - gap_buffer.gap_start
}

@[inline]
fn (gap_buffer GapBuffer) str() string {
	return gap_buffer.data[..gap_buffer.gap_start].string() +
		gap_buffer.data[gap_buffer.gap_end..].string()
}

@[inline]
fn (gap_buffer GapBuffer) runes() []rune {
	return gap_buffer.data
}

fn (gap_buffer GapBuffer) raw_str() string {
	mut sb := strings.new_builder(512)
	sb.write_runes(gap_buffer.data[..gap_buffer.gap_start])
	sb.write_string(strings.repeat_string('_', gap_buffer.gap_end - gap_buffer.gap_start))
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
	start_pos         Pos
	compound_x        int
	compound_y        int
	previous          rune
	set_previous      bool
	set_x_to_line_end bool
	done              bool
	res               ?Pos
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
	return Pos{
		x: s.start_pos.x + s.compound_x
		y: s.start_pos.y + s.compound_y
	}
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
	return Pos{
		x: s.start_pos.x + s.compound_x
		y: s.start_pos.y + s.compound_y
	}
}

// FIXME(tauraamui): I think this function doesn't need to include the gap as part of the offset'
fn (gap_buffer GapBuffer) find_offset(pos Position) ?int {
	pre_gap_data := gap_buffer.data[..gap_buffer.gap_start]

	mut line := 0
	mut line_offset := 0

	for offset, c in pre_gap_data {
		if line == pos.line && line_offset == pos.offset {
			return offset
		}

		if c == lf {
			line += 1
			line_offset = 0
			continue
		}

		line_offset += 1
	}

	if line == pos.line && line_offset == pos.offset {
		return gap_buffer.gap_start + (gap_buffer.gap_end - gap_buffer.gap_start)
	}

	post_gap_data := gap_buffer.data[gap_buffer.gap_start +
		(gap_buffer.gap_end - gap_buffer.gap_start)..]
	for offset, c in post_gap_data {
		if line == pos.line && line_offset == pos.offset {
			return gap_buffer.gap_start + (gap_buffer.gap_end - gap_buffer.gap_start) + offset
		}

		if c == lf {
			line += 1
			line_offset = 0
			continue
		}

		line_offset += 1
	}

	if line == pos.line && line_offset == pos.offset {
		return gap_buffer.data.len
	}

	return none
}

pub const lf = `\n`

// TODO(tauraamui) [16/03/2025]: paralellise this, one thread for pre-gap, one for post
pub fn (gap_buffer GapBuffer) num_of_lines() int {
	mut line_count := 0
	pre_gap_data := gap_buffer.data[..gap_buffer.gap_start]

	for _, c in pre_gap_data {
		if c == lf {
			line_count += 1
			continue
		}
	}

	post_gap_data := gap_buffer.data[gap_buffer.gap_start +
		(gap_buffer.gap_end - gap_buffer.gap_start)..]
	for _, c in post_gap_data {
		if c == lf {
			line_count += 1
			continue
		}
	}

	return line_count
}

struct LineIteratorFromGapBuffer {
	data string
mut:
	line_start int
	done       bool
}

fn new_gap_buffer_line_iterator(buffer GapBuffer) LineIterator {
	return LineIteratorFromGapBuffer{
		data: buffer.str()
	}
}

pub fn (mut iter LineIteratorFromGapBuffer) next() ?string {
	if iter.done {
		return none
	}
	mut line := ?string(none)
	for index in iter.line_start .. iter.data.len {
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

struct PatternMatchIteratorFromGapBuffer {
	pattern []rune
	data    []rune
mut:
	line_id   int
	line_iter LineIterator
	done      bool
}

fn new_gap_buffer_pattern_match_iterator(pattern []rune, buffer GapBuffer) PatternMatchIterator {
	mut data := buffer.runes()[..buffer.gap_start]
	data << buffer.runes()[buffer.gap_end..]
	return PatternMatchIteratorFromGapBuffer{
		pattern:   pattern
		line_iter: new_gap_buffer_line_iterator(buffer)
	}
}

pub fn (mut iter PatternMatchIteratorFromGapBuffer) next() ?Match {
	for {
		current_line_id := iter.line_id
		line_to_search := iter.line_iter.next() or {
			iter.done = true
			break
		}
		iter.line_id += 1
		found_index := search.kmp(line_to_search.runes(), iter.pattern)
		if found_index == -1 {
			continue
		}

		return Match{
			pos:      Position.new(
				offset: found_index
				line:   current_line_id
			)
			contents: line_to_search.runes()[found_index..found_index + iter.pattern.len].string()
		}
	}

	return none
}

pub fn (iter PatternMatchIteratorFromGapBuffer) done() bool {
	return iter.done
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
