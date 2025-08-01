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

import lib.search
import rand

pub type UUID_t = string

pub enum BufferKind as u8 {
	legacy
	line_buffer
	gap_buffer
}

pub struct Pos {
pub mut:
	x int
	y int
}

pub fn pos_to_position(pos ?Pos) Position {
	if unwrapped_pos := pos {
		return Position.new(line: unwrapped_pos.y, offset: unwrapped_pos.x)
	}
	return Position.new(line: 0, offset: 0)
}

pub fn position_to_pos(pos ?Position) Pos {
	if unwrapped_position := pos {
		return Pos{
			y: unwrapped_position.line
			x: unwrapped_position.offset
		}
	}
	return Pos{}
}

@[heap]
pub struct Buffer {
pub:
	use_gap_buffer bool
	uuid           UUID_t
	file_path      string
	buffer_kind    BufferKind
pub mut:
	auto_close_chars []string
	lines            []string
	dirty            bool
mut:
	l_buffer LineBuffer
	c_buffer GapBuffer
	// line_tracker LineTracker
}

pub fn Buffer.new(file_path string, b_kind BufferKind) Buffer {
	return Buffer{
		uuid:           rand.uuid_v4()
		file_path:      file_path
		buffer_kind:    b_kind
		use_gap_buffer: b_kind == .gap_buffer
	}
}

pub fn (mut buffer Buffer) read_lines(line_reader fn (path string) ![]string) ! {
	match buffer.buffer_kind {
		.gap_buffer {
			lines := line_reader(buffer.file_path) or {
				return error('unable to open file ${buffer.file_path}: ${err}')
			}
			buffer.load_contents_into_gap(lines.join('\n'))
		}
		.line_buffer {
			lines := line_reader(buffer.file_path) or {
				return error('unable to open file ${buffer.file_path}: ${err}')
			}
			buffer.load_contents_into_line_buffer(lines)
		}
		.legacy {
			buffer.lines = line_reader(buffer.file_path) or {
				return error('unable to open file ${buffer.file_path}: ${err}')
			}
			if buffer.lines.len == 0 {
				buffer.lines = ['']
			}
		}
	}
}

pub fn (mut buffer Buffer) load_contents_into_gap(contents string) {
	buffer.c_buffer = GapBuffer.new(contents)
}

pub fn (mut buffer Buffer) load_contents_into_line_buffer(contents []string) {
	buffer.l_buffer = LineBuffer.new(contents)
}

pub fn (buffer Buffer) num_of_lines() int {
	return match buffer.buffer_kind {
		.gap_buffer { buffer.c_buffer.num_of_lines() }
		.line_buffer { buffer.l_buffer.num_of_lines() }
		.legacy { buffer.lines.len }
	}
}

pub fn (mut buffer Buffer) move_data_cursor_to(pos Position) {
	match buffer.buffer_kind {
		.gap_buffer { buffer.c_buffer.move_cursor_to(pos) }
		else {} // moving cursor doesn't really mean anything for the other buffer types
	}
}

pub fn (mut buffer Buffer) insert_text(pos Position, s string) ?Position {
	match buffer.buffer_kind {
		.gap_buffer {
			mut cursor := position_to_pos(pos)
			for c in s.runes() {
				buffer.c_buffer.insert_at(c, Position.new(line: cursor.y, offset: cursor.x))
				cursor.x += 1
				if c == lf {
					cursor.y += 1
					cursor.x = 0
				}
			}
			return pos_to_position(cursor)
		}
		.line_buffer {
			return pos
		}
		.legacy {
			mut cursor := position_to_pos(pos)
			y := cursor.y
			mut line := buffer.lines[y]
			if line.len == 0 {
				buffer.lines[y] = '${s}'
				cursor.x = s.runes().len
				return pos_to_position(cursor)
			}

			if cursor.x > line.len {
				cursor.x = line.len
			}
			uline := line.runes()
			if cursor.x > uline.len {
				return pos_to_position(cursor)
			}
			left := uline[..cursor.x].string()
			right := uline[cursor.x..uline.len].string()
			buffer.lines[y] = '${left}${s}${right}'

			cursor.x += s.runes().len

			return pos_to_position(cursor)
		}
	}
}

// NOTE(tauraamui) [15/01/25]: I don't like the implications of the existence of this method,
//                             need to review all its potential usages and hopefully remove it.
pub fn (mut buffer Buffer) write_at(r rune, pos Position) {
	if buffer.buffer_kind != .gap_buffer {
		return
	}
	buffer.c_buffer.insert_at(r, pos)
}

pub fn (mut buffer Buffer) insert_tab(pos Position, tabs_not_spaces bool) ?Position {
	prefix := if tabs_not_spaces { '\t' } else { ' '.repeat(4) }
	match buffer.buffer_kind {
		.gap_buffer {
			buffer.move_data_cursor_to(pos)
			return buffer.insert_text(pos, prefix)
		}
		.line_buffer {
			return buffer.l_buffer.insert_tab(pos, tabs_not_spaces)
		}
		.legacy {
			return buffer.insert_text(pos, prefix)
		}
	}
}

pub fn (mut buffer Buffer) visual_indent(range Range, tabs_not_spaces bool) {
	for line_y := range.start.line; line_y <= range.end.line; line_y++ {
		buffer.insert_tab(Position.new(line: line_y, offset: 0), tabs_not_spaces)
	}
}

// NOTE(tauraamui) [26/06/2025]: this is effectively the newline insertion method.
//                               when moving these methods line based logic to "LineBuffer"
//                               it might be a good idea to take the opportunity to instead
//                               handle processing newlines just as their own special case for
//                               `text_insert`, but idk yet.
pub fn (mut buffer Buffer) enter(pos Position) ?Position {
	match buffer.buffer_kind {
		.gap_buffer {
			buffer.move_data_cursor_to(pos)
			return buffer.insert_text(pos, lf.str())
		}
		.line_buffer {
			return pos
		}
		.legacy {
			mut whitespace_prefix := resolve_whitespace_prefix_from_line_str(buffer.lines[pos.line])
			prefix_is_same_len_as_line := whitespace_prefix.len == buffer.lines[pos.line].len
			if prefix_is_same_len_as_line {
				buffer.lines[pos.line] = ''
				whitespace_prefix = ''
			}

			line := pos.line
			offset := if prefix_is_same_len_as_line { 0 } else { pos.offset }
			after_cursor := buffer.lines[line].runes()[offset..].string()
			buffer.lines[line] = buffer.lines[line].runes()[..offset].string()
			buffer.lines.insert(line + 1, '${whitespace_prefix}${after_cursor}')

			return pos.add(Distance{ offset: offset * -1 }).add(Distance{
				lines:  1
				offset: whitespace_prefix.len
			})
		}
	}
}

pub fn (mut buffer Buffer) delete_line(index int) {
	buffer.delete_line_range(index, index)
}

pub fn (mut buffer Buffer) delete_line_range(start int, end int) {
	if start == end {
		buffer.lines.delete(start)
		return
	}
	before := buffer.lines[..start]
	after := buffer.lines[end + 1..]

	buffer.lines = before
	buffer.lines << after
}

fn resolve_whitespace_prefix_from_line_str(line string) string {
	mut prefix_ends := 0
	for i, c in line {
		if !is_whitespace(c) {
			prefix_ends = i
			return line[..prefix_ends]
		}
	}
	return line
}

pub fn (mut buffer Buffer) x(pos Position) ?Position {
	match buffer.buffer_kind {
		.gap_buffer {
			// TODO(tauraamui): Move this stuff into gap buffer directly
			//                  as there's now confusion as to which methods here
			//                  can be safely used by the gap buffer impl and which
			//                  can not.
			return pos_to_position(buffer.c_buffer.x(position_to_pos(pos)) or {
				position_to_pos(pos)
			})
		}
		.line_buffer {
			return buffer.l_buffer.x(pos)
		}
		.legacy {
			mut cursor := position_to_pos(pos)
			line := buffer.lines[cursor.y].runes()
			if line.len == 0 {
				return none
			}
			start := line[..cursor.x]
			end := line[cursor.x + 1..]
			buffer.lines[cursor.y] = '${start.string()}${end.string()}'
			return pos_to_position(buffer.clamp_cursor_x_pos(buffer.clamp_cursor_within_document_bounds(cursor),
				false))
		}
	}
}

// TODO(tauraamui) [10/07/2025]: migrate this to gap and line buffers more completely
// TODO(tauraamui) [28/07/2025]: properly refactor this to really use the new position type
//                               more completely, for example we stop using the convertion functions
//                               and actually instantiate a new, well instance of position using the
//                               constructor
pub fn (mut buffer Buffer) backspace(pos Position) ?Position {
	match buffer.buffer_kind {
		.gap_buffer {
			mut cursor := position_to_pos(pos)
			if cursor.x == 0 && cursor.y == 0 {
				return none
			}
			if buffer.use_gap_buffer {
				buffer.move_data_cursor_to(pos)
				if buffer.c_buffer.backspace() {
					cursor.y -= 1
					cursor.x = buffer.find_end_of_line(cursor) or { 0 }
					return pos_to_position(cursor)
				}
				cursor.x -= 1
				if cursor.x < 0 {
					cursor.x = 0
				}
				return pos_to_position(cursor)
			}
		}
		.line_buffer {
			return none
		}
		.legacy {
			mut cursor := position_to_pos(pos)
			if cursor.x == 0 && cursor.y == 0 {
				return none
			}
			mut line := buffer.lines[cursor.y]
			if cursor.x == 0 {
				previous_line := buffer.lines[cursor.y - 1]
				buffer.lines[cursor.y - 1] = '${previous_line}${buffer.lines[cursor.y]}'
				buffer.lines.delete(cursor.y)
				cursor.y -= 1
				cursor = buffer.clamp_cursor_within_document_bounds(cursor)
				cursor.x = previous_line.len

				if cursor.y < 0 {
					cursor.y = 0
				}
				return pos_to_position(cursor)
			}

			if cursor.x == line.len {
				buffer.lines[cursor.y] = line.runes()[..line.len - 1].string()
				cursor.x = buffer.lines[cursor.y].len
				return pos_to_position(cursor)
			}

			before := line.runes()[..cursor.x - 1].string()
			after := line.runes()[cursor.x..].string()
			buffer.lines[cursor.y] = '${before}${after}'
			cursor.x -= 1
			if cursor.x < 0 {
				cursor.x = 0
			}

			return pos_to_position(cursor)
		}
	}
	return none
}

pub fn (mut buffer Buffer) delete(ignore_newlines bool) bool {
	return match buffer.buffer_kind {
		.gap_buffer { buffer.c_buffer.delete(ignore_newlines) }
		else { false }
	}
}

pub fn (mut buffer Buffer) o(pos Position) ?Position {
	// NOTE(tauraamui) [28/07/2025]: the commented code is basically the dream
	//                               but we have to deprecate the legacy stuff first
	/*
	buff := match buffer.buffer_kind {
		.gap_buffer { buffer.c_buffer }
		.line_buffer { buffer.l_buffer }
	}
	return buff.o(pos) or { pos }
	*/
	match buffer.buffer_kind {
		.gap_buffer {
			return buffer.c_buffer.o(pos) or { pos }
		}
		.line_buffer {
			return buffer.l_buffer.o(pos) or { pos }
		}
		.legacy {
			mut cursor := position_to_pos(pos)
			y := pos.line
			mut whitespace_prefix := resolve_whitespace_prefix_from_line_str(buffer.lines[y])
			if whitespace_prefix.len == buffer.lines[y].len {
				buffer.lines[y] = ''
				whitespace_prefix = ''
				cursor.x = 0
			}
			cursor.y += 1
			cursor.x = whitespace_prefix.len
			if y >= buffer.lines.len {
				buffer.lines << whitespace_prefix
				return pos_to_position(cursor)
			}
			buffer.lines.insert(y + 1, whitespace_prefix)
			return pos_to_position(cursor)
		}
	}
}

pub fn (buffer Buffer) read_line(y int) ?string {
	if lines := buffer.read(Range.new(Position.new(line: y, offset: 0), Position.new(
		line:   y
		offset: 0
	)))
	{
		return lines[0]
	}
	return none
}

pub fn (buffer Buffer) read(range Range) ?[]string {
	if buffer.use_gap_buffer {
		if data := buffer.c_buffer.read(range) {
			return data.split('${lf}')
		} else {
			return ?[]string(none)
		}
	}
	return ?[]string(none)
}

pub fn (mut buffer Buffer) str() string {
	return match buffer.buffer_kind {
		.gap_buffer { buffer.c_buffer.str() }
		.line_buffer { buffer.l_buffer.str() }
		.legacy { buffer.lines.join('\n') }
	}
}

pub fn (mut buffer Buffer) raw_str() string {
	return buffer.c_buffer.raw_str()
}

// *
// NOTE(tauraamui) [13/07/2025]: pretty sure these are unused, or if they are, we want to get rid
pub fn (buffer Buffer) find_end_of_line(pos Pos) ?int {
	return buffer.c_buffer.find_end_of_line(pos)
}

pub fn (buffer Buffer) find_next_word_start(pos Pos) ?Pos {
	return buffer.c_buffer.find_next_word_start(pos)
}

pub fn (buffer Buffer) find_next_word_end(pos Pos) ?Pos {
	return buffer.c_buffer.find_next_word_end(pos)
}

pub fn (buffer Buffer) find_prev_word_start(pos Pos) ?Pos {
	return buffer.c_buffer.find_prev_word_start(pos)
}

// *

pub fn (buffer Buffer) left(pos Position, insert_mode bool) ?Position {
	match buffer.buffer_kind {
		.gap_buffer {
			return if p := buffer.c_buffer.left(position_to_pos(pos)) {
				pos_to_position(p)
			} else {
				pos
			}
		}
		.line_buffer {
			return buffer.l_buffer.left(pos)
		}
		.legacy {
			mut cursor := position_to_pos(pos)
			cursor.x -= 1
			cursor = buffer.clamp_cursor_x_pos(cursor, insert_mode)
			return pos_to_position(cursor)
		}
	}
}

pub fn (buffer Buffer) right(pos Position, insert_mode bool) ?Position {
	match buffer.buffer_kind {
		.gap_buffer {
			return if p := buffer.c_buffer.right(position_to_pos(pos), insert_mode) {
				pos_to_position(p)
			} else {
				pos
			}
		}
		.line_buffer {
			return buffer.l_buffer.right(pos, insert_mode)
		}
		.legacy {
			mut cursor := position_to_pos(pos)
			cursor.x += 1
			cursor = buffer.clamp_cursor_x_pos(cursor, insert_mode)
			return pos_to_position(cursor)
		}
	}
}

pub fn (buffer Buffer) down(pos Position, insert_mode bool) ?Position {
	match buffer.buffer_kind {
		.gap_buffer {
			return if p := buffer.c_buffer.down(position_to_pos(pos)) {
				pos_to_position(p)
			} else {
				pos
			}
		}
		.line_buffer {
			return buffer.l_buffer.down(pos, insert_mode)
		}
		.legacy {
			mut cursor := position_to_pos(pos)
			cursor.y += 1
			if cursor.y >= buffer.lines.len - 1 {
				cursor.y = buffer.lines.len - 1
			}
			cursor = buffer.clamp_cursor_x_pos(cursor, insert_mode)
			return pos_to_position(cursor)
		}
	}
}

pub fn (buffer Buffer) up(pos Position, insert_mode bool) ?Position {
	match buffer.buffer_kind {
		.gap_buffer {
			return if p := buffer.c_buffer.up(position_to_pos(pos)) {
				pos_to_position(p)
			} else {
				pos
			}
		}
		.line_buffer {
			return buffer.l_buffer.up(pos, insert_mode)
		}
		.legacy {
			mut cursor := position_to_pos(pos)
			cursor.y -= 1
			if cursor.y < 0 {
				cursor.y = 0
			}
			cursor = buffer.clamp_cursor_x_pos(cursor, insert_mode)
			return pos_to_position(cursor)
		}
	}
}

pub fn (buffer Buffer) up_to_next_blank_line(pos Position) ?Position {
	match buffer.buffer_kind {
		.gap_buffer {
			return if p := buffer.c_buffer.up_to_next_blank_line(position_to_pos(pos)) {
				pos_to_position(p)
			} else {
				none
			}
		}
		.line_buffer {
			return buffer.l_buffer.up_to_next_blank_line(pos)
		}
		.legacy {
			mut cursor := position_to_pos(pos)
			cursor = buffer.clamp_cursor_within_document_bounds(cursor)
			if cursor.y == 0 {
				return none
			}

			if buffer.lines.len == 0 {
				return none
			}

			mut compound_y := 0
			for i := cursor.y; i >= 0; i-- {
				if i == cursor.y {
					continue
				}
				compound_y += 1
				if buffer.lines[i].len == 0 {
					break
				}
			}

			if compound_y > 0 {
				cursor.x = 0
				cursor.y -= compound_y
				return pos_to_position(cursor)
			}
		}
	}
	return none
}

pub fn (buffer Buffer) down_to_next_blank_line_new(pos Pos) ?Pos {
	match buffer.buffer_kind {
		.gap_buffer {
			return buffer.c_buffer.down_to_next_blank_line(pos)
		}
		.line_buffer {
			return position_to_pos(buffer.l_buffer.down_to_next_blank_line(Position.new(
				line:   pos.y
				offset: pos.x
			)))
		}
		.legacy {
			mut cursor := pos
			cursor = buffer.clamp_cursor_within_document_bounds(pos)

			if buffer.lines.len == 0 {
				return none
			}
			if cursor.y == buffer.lines.len {
				return none
			}

			mut compound_y := 0
			for i := cursor.y; i < buffer.lines.len; i++ {
				if i == cursor.y {
					continue
				}
				compound_y += 1
				if buffer.lines[i].len == 0 {
					break
				}
			}

			if compound_y > 0 {
				cursor.x = 0
				cursor.y += compound_y
				return cursor
			}

			return none
		}
	}
}

pub fn (buffer Buffer) down_to_next_blank_line(pos Pos) ?Pos {
	match buffer.buffer_kind {
		.gap_buffer {
			return buffer.c_buffer.down_to_next_blank_line(pos)
		}
		.line_buffer {
			return position_to_pos(buffer.l_buffer.down_to_next_blank_line(Position.new(
				line:   pos.y
				offset: pos.x
			)))
		}
		.legacy {
			mut cursor := pos
			cursor = buffer.clamp_cursor_within_document_bounds(pos)

			if buffer.lines.len == 0 {
				return none
			}
			if cursor.y == buffer.lines.len {
				return none
			}

			mut compound_y := 0
			for i := cursor.y; i < buffer.lines.len; i++ {
				if i == cursor.y {
					continue
				}
				compound_y += 1
				if buffer.lines[i].len == 0 {
					break
				}
			}

			if compound_y > 0 {
				cursor.x = 0
				cursor.y += compound_y
				return cursor
			}

			return none
		}
	}
}

pub fn (mut buffer Buffer) replace_char(pos Pos, code u8, str string) {
	if buffer.use_gap_buffer {
		assert true == false
		return
	}

	if code < 32 {
		return
	}
	cursor := pos
	line := buffer.lines[pos.y].runes()
	start := line[..cursor.x]
	end := line[cursor.x + 1..]
	buffer.lines[cursor.y] = '${start.string()}${str}${end.string()}'
}

pub fn (buffer Buffer) clamp_cursor_within_document_bounds_new(pos Position) Position {
	return pos.add(Distance{
		lines: if pos.line > buffer.lines.len - 1 {
			(pos.line - (buffer.lines.len - 1))
		} else {
			0
		} * -1
	})
}

pub fn (buffer Buffer) clamp_cursor_within_document_bounds(pos Pos) Pos {
	mut cursor := pos
	if pos.y < 0 {
		cursor.y = 0
	}
	if cursor.y > buffer.lines.len - 1 {
		cursor.y = buffer.lines.len - 1
	}
	return cursor
}

pub fn (buffer Buffer) clamp_cursor_x_pos(pos Pos, insert_mode bool) Pos {
	// mut clamped := buffer.clamp_cursor_within_document_bounds(pos)
	mut clamped := pos
	if clamped.x < 0 {
		clamped.x = 0
	}

	current_line_len := buffer.lines[pos.y].runes().len

	if insert_mode {
		if clamped.x > current_line_len {
			clamped.x = current_line_len
		}
	} else {
		diff := pos.x - (current_line_len - 1)
		if diff > 0 {
			clamped.x = current_line_len - 1
		}
	}
	if clamped.x < 0 {
		clamped.x = 0
	}
	return clamped
}

pub interface PatternMatchIterator {
	done() bool
mut:
	next() ?Match
}

pub struct Match {
pub:
	file_path   string
	pos         Pos
	keyword_len int
	contents    string
}

struct PatternMatchIteratorFromLinesList {
	file_path string
	pattern   []rune
	data_ref  []string
mut:
	idx  int
	done bool
}

const forward_slash = '/'.runes()[0]
const star = '*'.runes()[0]

// -x TODO(tauraamui) [07/03/2025]: need to implement some attribute or tag to exclude comments from the matcher
pub fn (mut iter PatternMatchIteratorFromLinesList) next() ?Match {
	if iter.idx >= iter.data_ref.len {
		iter.done = true
		return none
	}
	defer { iter.idx += 1 }

	// search for pattern within line
	// NOTE(tauraamui): for the buffer that contains the document in a list/array of strings, one string per line
	//                  doing this descrete pattern search per line makes sense, however ordinarilly I don't want
	//                  to do pattern searches in pieces, one piece per line but more of searching within "blocks"
	//                  of data that doesn't start and end with a newline.
	line_to_search := iter.data_ref[iter.idx].runes()
	found_index := search.kmp(line_to_search, iter.pattern)
	if found_index == -1 {
		return none
	}

	mut found_match := Match{
		file_path:   iter.file_path
		pos:         Pos{
			x: found_index
			y: iter.idx
		}
		contents:    line_to_search[found_index..].string()
		keyword_len: iter.pattern.len
	}

	if find_comment_prefix(line_to_search, found_index) {
		return found_match
	}

	return none
}

fn find_comment_prefix(line_to_search []rune, start_index int) bool {
	for i := start_index; i >= 0; i -= 1 {
		match line_to_search[i] {
			// any comment with -x before the keyword will be excluded
			'x'.runes()[0] {
				if i - 1 >= 0 {
					if line_to_search[i - 1] == '-'.runes()[0] {
						return false
					}
				}
			}
			forward_slash {
				if i - 1 >= 0 {
					if line_to_search[i - 1] == forward_slash {
						return true
					}
				}
			}
			star {
				if i - 1 >= 0 {
					if line_to_search[i - 1] == forward_slash {
						return true
					}
				}
			}
			else {}
		}
	}
	return false
}

pub fn (iter PatternMatchIteratorFromLinesList) done() bool {
	return iter.done
}

pub fn (buffer Buffer) match_iterator(pattern []rune) PatternMatchIterator {
	// if buffer.use_gap_buffer {}
	if buffer.use_gap_buffer {
		return new_gap_buffer_pattern_match_iterator(pattern, buffer.c_buffer)
	}
	return PatternMatchIteratorFromLinesList{
		file_path: buffer.file_path
		data_ref:  buffer.lines
		pattern:   pattern
	}
}

pub interface LineIterator {
mut:
	next() ?string
}

struct LineIteratorFromLinesList {
	data_ref []string
mut:
	idx int
}

pub fn (mut iter LineIteratorFromLinesList) next() ?string {
	if iter.idx >= iter.data_ref.len {
		return none
	}
	defer { iter.idx += 1 }
	return iter.data_ref[iter.idx]
}

pub fn (buffer Buffer) line_iterator() LineIterator {
	if buffer.use_gap_buffer {
		return new_gap_buffer_line_iterator(buffer.c_buffer)
	}
	return LineIteratorFromLinesList{
		data_ref: buffer.lines
	}
}
