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

fn test_buffer_load_from_path() {
	line_reader := fn (path string) ![]string {
		return ['1. This is a first line', '2. This is a second line', '3. This is a third line']
	}

	mut buffer := Buffer.new('', .legacy)
	buffer.read_lines(line_reader)!

	assert buffer.lines == ['1. This is a first line', '2. This is a second line',
		'3. This is a third line']
}

fn test_buffer_load_from_path_and_iterate() {
	line_reader := fn (path string) ![]string {
		return ['1. This is a first line', '2. This is a second line', '3. This is a third line']
	}

	mut buffer := Buffer.new('', .legacy)
	buffer.read_lines(line_reader)!

	assert buffer.lines == ['1. This is a first line', '2. This is a second line',
		'3. This is a third line']

	mut iteration_count := 0
	for id, line in buffer.line_iterator() {
		iteration_count += 1
		match id {
			0 { assert line == '1. This is a first line' }
			1 { assert line == '2. This is a second line' }
			2 { assert line == '3. This is a third line' }
			else {}
		}
	}

	assert iteration_count == 3
}

fn test_buffer_load_from_path_with_gap_buffer_and_iterate() {
	line_reader := fn (path string) ![]string {
		return ['1. This is a first line', '2. This is a second line', '3. This is a third line']
	}

	mut buffer := Buffer.new('', .gap_buffer)
	buffer.read_lines(line_reader)!

	mut iteration_count := 0
	for id, line in buffer.line_iterator() {
		iteration_count += 1
		match id {
			0 { assert line == '1. This is a first line' }
			1 { assert line == '2. This is a second line' }
			2 { assert line == '3. This is a third line' }
			else {}
		}
	}

	assert iteration_count == 3
}

fn test_buffer_load_from_path_and_iterate_over_pattern_matches() {
	line_reader := fn (path string) ![]string {
		return ['1. This is a first line',
			'// TODO(tauraamui) [30/01/25]: this line has a comment to find',
			'2. This is a second line', '3. This is a third line']
	}

	mut buffer := Buffer.new('', .legacy)
	buffer.read_lines(line_reader)!

	mut iteration_count := 0
	mut found_match_count := 0
	mut match_iter := buffer.match_iterator('TODO'.runes())
	for !match_iter.done() {
		iteration_count += 1
		found_match := match_iter.next() or { continue }
		found_match_count += 1
		assert found_match == Match{
			pos: Position.new(
				line: 1
				offset: 3
			)
			contents:    'TODO(tauraamui) [30/01/25]: this line has a comment to find'
			keyword_len: 4
		}
	}

	assert found_match_count == 1
	assert iteration_count == 5
}

fn test_buffer_load_from_path_and_iterate_over_pattern_matches_excluding_matches_not_within_comment() {
	line_reader := fn (path string) ![]string {
		return [
			'1. This is a first line',
			'// TODO(tauraamui) [30/01/25]: this line has a comment to find',
			'2. This is a second line',
			'3. This line contains TODO but not in a comment',
			'4. This is the fourth line',
		]
	}

	mut buffer := Buffer.new('', .legacy)
	buffer.read_lines(line_reader)!

	mut found_matches := []Match{}

	mut iteration_count := 0
	mut match_iter := buffer.match_iterator('TODO'.runes())
	for !match_iter.done() {
		iteration_count += 1
		found_match := match_iter.next() or { continue }
		found_matches << found_match
	}

	assert found_matches.len == 1
	assert found_matches[0] == Match{
		pos: Position.new(
			line: 1
			offset: 3
		)
		contents:    'TODO(tauraamui) [30/01/25]: this line has a comment to find'
		keyword_len: 4
	}
	assert iteration_count == 6
}

fn test_buffer_load_from_path_and_iterate_over_pattern_matches_excluding_matches_within_comment_with_exclusion_prefix() {
	line_reader := fn (path string) ![]string {
		return [
			'1. This is a first line',
			'// -x TODO(tauraamui) [30/01/25]: this line has a comment to find',
			'// TODO(tauraamui) [30/01/25]: comment without exclusion prefix 2. This is a second line',
			'3. This line contains nothing',
			'4. This is the fourth line',
		]
	}

	mut buffer := Buffer.new('', .legacy)
	buffer.read_lines(line_reader)!

	mut found_matches := []Match{}

	mut iteration_count := 0
	mut match_iter := buffer.match_iterator('TODO'.runes())
	for !match_iter.done() {
		iteration_count += 1
		found_match := match_iter.next() or { continue }
		found_matches << found_match
	}

	assert found_matches.len == 1
	assert found_matches[0] == Match{
		pos: Position.new(
			line: 2
			offset: 3
		)
		contents:    'TODO(tauraamui) [30/01/25]: comment without exclusion prefix 2. This is a second line'
		keyword_len: 4
	}
	assert iteration_count == 6
}

fn test_buffer_load_from_path_with_gap_buffer_and_iterate_over_pattern_matches() {
	line_reader := fn (path string) ![]string {
		return ['1. This is a first line',
			'// TODO(tauraamui) [30/01/25]: this line has a comment to find',
			'2. This is a second line', '3. This is a third line']
	}

	mut buffer := Buffer.new('', .gap_buffer)
	buffer.read_lines(line_reader)!

	mut iteration_count := 0
	mut found_match_count := 0
	mut match_iter := buffer.match_iterator('TODO'.runes())
	for !match_iter.done() {
		iteration_count += 1
		found_match := match_iter.next() or { continue }
		found_match_count += 1
		assert found_match == Match{
			pos: Position.new(
				line: 1
				offset: 3
			)
			contents: 'TODO'
		}
	}

	assert found_match_count == 1
	assert iteration_count == 2
}

fn test_buffer_clamp_cursor_within_document_bounds() {
	mut buffer := Buffer.new('', .legacy)
	buffer.lines = ['1. first line', '2. second line', '3. third line']
	assert buffer.clamp_cursor_within_document_bounds(Position.new(line: -10, offset: 0)) == Position.new(
		line:   0
		offset: 0
	)
	assert buffer.clamp_cursor_within_document_bounds(Position.new(line: 1, offset: 0)) == Position.new(
		line:   1
		offset: 0
	)
	assert buffer.clamp_cursor_within_document_bounds(Position.new(line: 2, offset: 0)) == Position.new(
		line:   2
		offset: 0
	)
	assert buffer.clamp_cursor_within_document_bounds(Position.new(line: 19, offset: 0)) == Position.new(
		line:   2
		offset: 0
	)
}

fn test_buffer_gap_buffer_insert_text() {
	mut buffer := Buffer.new('', .gap_buffer)
	buffer.c_buffer = GapBuffer.new('')

	for r in 'Some text to insert!'.runes() {
		buffer.c_buffer.insert(r)
	}

	assert buffer.str() == 'Some text to insert!'
}

fn test_buffer_gap_buffer_enter_inserts_newline_line() {
	mut buffer := Buffer.new('', .gap_buffer)
	buffer.c_buffer = GapBuffer.new('1. first line\n2. second line\n3. third line')
	buffer.enter(Position.new(line: 0, offset: 4))
	assert buffer.str() == '1. f\nirst line\n2. second line\n3. third line'
}

fn test_buffer_legacy_buffer_enter_inserts_newline_line() {
	mut buffer := Buffer.new('', .legacy)
	buffer.lines = ['1. first line', '2. second line', '3. third line']
	buffer.enter(Position.new(line: 0, offset: 4))
	assert buffer.str() == '1. f\nirst line\n2. second line\n3. third line'
}

fn test_buffer_line_buffer_enter_inserts_newline_line() {
	mut buffer := Buffer.new('', .line_buffer)
	buffer.load_contents_into_line_buffer(['1. first line', '2. second line', '3. third line'])
	buffer.enter(Position.new(line: 0, offset: 4))
	// NOTE(tauraamui) [23/07/2025]: currently the line buffer version of this method
	//                               does nothing, and is therefore not expected to mutate
	//                               the document by inserting any newlines
	assert buffer.str() == '1. first line\n2. second line\n3. third line'
}

fn test_buffer_gap_buffer_x_deletes_char_from_line() {
	mut buffer := Buffer.new('', .gap_buffer)
	buffer.c_buffer = GapBuffer.new('1. first line\n2. second line\n3. third line')

	mut new_pos := buffer.x(Position.new(line: 0, offset: 4))?
	assert new_pos == Position.new(line: 0, offset: 4)

	assert buffer.str() == '1. frst line\n2. second line\n3. third line'

	new_pos = buffer.x(new_pos)?
	assert new_pos == Position.new(line: 0, offset: 4)
	assert buffer.str() == '1. fst line\n2. second line\n3. third line'
}

fn test_buffer_legacy_buffer_x_deletes_char_from_line() {
	mut buffer := Buffer.new('', .legacy)
	buffer.lines = ['1. first line', '2. second line', '3. third line']

	mut new_pos := buffer.x(Position.new(line: 0, offset: 4))?
	assert new_pos == Position.new(line: 0, offset: 4)

	assert buffer.str() == '1. frst line\n2. second line\n3. third line'

	new_pos = buffer.x(new_pos)?
	assert new_pos == Position.new(line: 0, offset: 4)
	assert buffer.str() == '1. fst line\n2. second line\n3. third line'
}

fn test_buffer_line_buffer_x_deletes_char_from_line() {
	mut buffer := Buffer.new('', .line_buffer)
	lines := ['1. first line', '2. second line', '3. third line']
	buffer.load_contents_into_line_buffer(lines)

	mut new_pos := buffer.x(Position.new(line: 0, offset: 4))?
	assert new_pos == Position.new(line: 0, offset: 4)
	assert buffer.str() == '1. frst line\n2. second line\n3. third line'

	new_pos = buffer.x(new_pos)?
	assert new_pos == Position.new(line: 0, offset: 4)
	assert buffer.str() == '1. fst line\n2. second line\n3. third line'
}

fn test_buffer_gap_buffer_enter_inserts_newline() {
	mut buffer := Buffer.new('', .gap_buffer)
	buffer.c_buffer = GapBuffer.new('1. first line\n2. second line\n3. third line')

	mut new_pos := buffer.enter(Position.new(line: 0, offset: 4))?
	assert new_pos == Position.new(line: 1, offset: 0)

	assert buffer.str() == '1. f\nirst line\n2. second line\n3. third line'

	new_pos = buffer.enter(new_pos)?
	assert new_pos == Position.new(line: 2, offset: 0)
	assert buffer.str() == '1. f\n\nirst line\n2. second line\n3. third line'
}

fn test_buffer_legacy_buffer_enter_inserts_newline() {
	mut buffer := Buffer.new('', .legacy)
	buffer.lines = ['1. first line', '2. second line', '3. third line']

	mut new_pos := buffer.enter(Position.new(line: 0, offset: 4))?
	assert new_pos == Position.new(line: 1, offset: 0)

	assert buffer.str() == '1. f\nirst line\n2. second line\n3. third line'

	new_pos = buffer.enter(new_pos)?
	assert new_pos == Position.new(line: 2, offset: 0)
	assert buffer.str() == '1. f\n\nirst line\n2. second line\n3. third line'
}

fn test_buffer_line_buffer_enter_inserts_newline() {
	mut buffer := Buffer.new('', .line_buffer)
	lines := ['1. first line', '2. second line', '3. third line']
	buffer.load_contents_into_line_buffer(lines)

	mut new_pos := buffer.enter(Position.new(line: 0, offset: 4))?
	assert new_pos == Position.new(line: 0, offset: 4)
	assert buffer.str() == '1. first line\n2. second line\n3. third line'

	new_pos = buffer.enter(new_pos)?
	assert new_pos == Position.new(line: 0, offset: 4)
	assert buffer.str() == '1. first line\n2. second line\n3. third line'
}

fn test_buffer_gap_buffer_delete_deletes_char_from_line() {
	mut buffer := Buffer.new('', .gap_buffer)
	buffer.c_buffer = GapBuffer.new('1. first line\n2. second line\n3. third line')

	assert buffer.delete(false)
	assert buffer.str() == '. first line\n2. second line\n3. third line'
}

fn test_buffer_legacy_buffer_delete_does_nothing() {
	mut buffer := Buffer.new('', .legacy)
	lines := ['1. first line', '2. second line', '3. third line']
	buffer.lines = lines

	assert buffer.delete(false) == false
	assert buffer.str() == '1. first line\n2. second line\n3. third line'
}

fn test_buffer_line_buffer_delete_does_nothing() {
	mut buffer := Buffer.new('', .line_buffer)
	lines := ['1. first line', '2. second line', '3. third line']
	buffer.load_contents_into_line_buffer(lines)

	assert buffer.delete(false) == false
	assert buffer.str() == '1. first line\n2. second line\n3. third line'
}

fn test_buffer_gap_buffer_o_inserts_newline() {
	mut buffer := Buffer.new('', .gap_buffer)
	buffer.c_buffer = GapBuffer.new('1. first line\n2. second line\n3. third line')

	new_pos := buffer.o(Position.new(line: 1, offset: 3))?
	assert new_pos == Position.new(line: 2, offset: 0)
	assert buffer.str() == '1. first line\n2. second line\n\n3. third line'
}

fn test_buffer_legacy_buffer_o_inserts_newline() {
	mut buffer := Buffer.new('', .legacy)
	lines := ['1. first line', '2. second line', '3. third line']
	buffer.lines = lines

	new_pos := buffer.o(Position.new(line: 1, offset: 3))?
	assert new_pos == Position.new(line: 2, offset: 0)
	assert buffer.str() == '1. first line\n2. second line\n\n3. third line'
}

fn test_buffer_line_buffer_o_inserts_newline() {
	mut buffer := Buffer.new('', .line_buffer)
	lines := ['1. first line', '2. second line', '3. third line']
	buffer.load_contents_into_line_buffer(lines)

	new_pos := buffer.o(Position.new(line: 1, offset: 3))?
	assert new_pos == Position.new(line: 2, offset: 0)
	assert buffer.str() == '1. first line\n2. second line\n\n3. third line'
}

fn test_buffer_gap_buffer_backspace_deletes_char_from_line() {
	mut buffer := Buffer.new('', .gap_buffer)
	buffer.c_buffer = GapBuffer.new('1. first line\n2. second line\n3. third line')

	mut new_pos := buffer.backspace(Position.new(line: 0, offset: 4))?
	assert new_pos == Position.new(line: 0, offset: 3)

	assert buffer.str() == '1. irst line\n2. second line\n3. third line'

	new_pos = buffer.backspace(new_pos)?
	assert new_pos == Position.new(line: 0, offset: 2)
	assert buffer.str() == '1.irst line\n2. second line\n3. third line'
}

fn test_buffer_legacy_buffer_backspace_deletes_char_from_line() {
	mut buffer := Buffer.new('', .legacy)
	buffer.lines = ['1. first line', '2. second line', '3. third line']

	mut new_pos := buffer.backspace(Position.new(line: 0, offset: 4))?
	assert new_pos == Position.new(line: 0, offset: 3)

	assert buffer.str() == '1. irst line\n2. second line\n3. third line'

	new_pos = buffer.backspace(new_pos)?
	assert new_pos == Position.new(line: 0, offset: 2)
	assert buffer.str() == '1.irst line\n2. second line\n3. third line'
}

// NOTE(tauraamui) [26/07/2025]: line buffer backspace is currently a noop,
//                               this is currently intended behaviour, so the
//                               test for now should check for nothing at all
fn test_buffer_line_buffer_backspace_deletes_char_from_line() {
	mut buffer := Buffer.new('', .line_buffer)
	lines := ['1. first line', '2. second line', '3. third line']
	buffer.load_contents_into_line_buffer(lines)

	/*
	mut new_pos := buffer.backspace(Pos{ x: 4, y: 0 })?
	assert new_pos == Pos{
		x: 3
		y: 0
	}

	assert buffer.str() == '1. irst line\n2. second line\n3. third line'

	new_pos = buffer.backspace(new_pos)?
	assert new_pos == Pos{
		x: 2
		y: 0
	}
	assert buffer.str() == '1.irst line\n2. second line\n3. third line'
	*/
}

fn test_replace_char() {
	mut buffer := Buffer.new('', .legacy)
	lines := ['1. first line', '2. second line', '3. third line']
	buffer.lines = lines

	assert buffer.str() == '1. first line\n2. second line\n3. third line'

	buffer.replace_char(Position.new(line: 0, offset: 7), 113, 'q')
	assert buffer.str() == '1. firsq line\n2. second line\n3. third line'

	buffer.replace_char(Position.new(line: 1, offset: 11), 112, 'p')
	assert buffer.str() == '1. firsq line\n2. second lpne\n3. third line'
}

fn test_buffer_gap_buffer_left_moves_cursor_left_successfully() {
	mut buffer := Buffer.new('', .gap_buffer)
	buffer.c_buffer = GapBuffer.new('1. first line\n2. second line\n3. third line')

	new_pos := buffer.left(Position.new(line: 1, offset: 3), false)?
	assert new_pos == Position.new(line: 1, offset: 2)
	assert buffer.str() == '1. first line\n2. second line\n3. third line'
}

fn test_buffer_legacy_buffer_left_moves_cursor_left_successfully() {
	mut buffer := Buffer.new('', .legacy)
	lines := ['1. first line', '2. second line', '3. third line']
	buffer.lines = lines

	new_pos := buffer.left(Position.new(line: 1, offset: 3), false)?
	assert new_pos == Position.new(line: 1, offset: 2)
	assert buffer.str() == '1. first line\n2. second line\n3. third line'
}

fn test_buffer_line_buffer_left_moves_cursor_left_successfully() {
	mut buffer := Buffer.new('', .line_buffer)
	lines := ['1. first line', '2. second line', '3. third line']
	buffer.load_contents_into_line_buffer(lines)

	new_pos := buffer.left(Position.new(line: 1, offset: 3), false)?
	assert new_pos == Position.new(line: 1, offset: 2)
	assert buffer.str() == '1. first line\n2. second line\n3. third line'
}

fn test_buffer_gap_buffer_right_moves_cursor_right_successfully() {
	mut buffer := Buffer.new('', .gap_buffer)
	buffer.load_contents_into_gap('1. first line\n2. second line\n3. third line')

	new_pos := buffer.right(Position.new(line: 1, offset: 3), false)?
	assert new_pos == Position.new(line: 1, offset: 4)
	assert buffer.str() == '1. first line\n2. second line\n3. third line'
}

fn test_buffer_legacy_buffer_right_moves_cursor_right_successfully() {
	mut buffer := Buffer.new('', .legacy)
	lines := ['1. first line', '2. second line', '3. third line']
	buffer.lines = lines

	new_pos := buffer.right(Position.new(line: 1, offset: 2), false)?
	assert new_pos == Position.new(line: 1, offset: 3)
	assert buffer.str() == '1. first line\n2. second line\n3. third line'
}

fn test_buffer_line_buffer_right_moves_cursor_right_successfully() {
	mut buffer := Buffer.new('', .line_buffer)
	lines := ['1. first line', '2. second line', '3. third line']
	buffer.load_contents_into_line_buffer(lines)

	new_pos := buffer.right(Position.new(line: 1, offset: 3), false)?
	assert new_pos == Position.new(line: 1, offset: 4)
	assert buffer.str() == '1. first line\n2. second line\n3. third line'
}

fn test_buffer_gap_buffer_down_moves_cursor_down_successfully() {
	mut buffer := Buffer.new('', .gap_buffer)
	buffer.load_contents_into_gap('1. first line\n2. second line\n3. third line')

	new_pos := buffer.down(Position.new(line: 1, offset: 3), false)?
	assert new_pos == Position.new(line: 2, offset: 3)
	assert buffer.str() == '1. first line\n2. second line\n3. third line'
}

fn test_buffer_legacy_buffer_down_moves_cursor_down_successfully() {
	mut buffer := Buffer.new('', .legacy)
	lines := ['1. first line', '2. second line', '3. third line']
	buffer.lines = lines

	new_pos := buffer.down(Position.new(line: 1, offset: 2), false)?
	assert new_pos == Position.new(line: 2, offset: 2)
	assert buffer.str() == '1. first line\n2. second line\n3. third line'
}

fn test_buffer_line_buffer_down_moves_cursor_down_successfully() {
	mut buffer := Buffer.new('', .line_buffer)
	lines := ['1. first line', '2. second line', '3. third line']
	buffer.load_contents_into_line_buffer(lines)

	new_pos := buffer.down(Position.new(line: 1, offset: 3), false)?
	assert new_pos == Position.new(line: 2, offset: 3)
	assert buffer.str() == '1. first line\n2. second line\n3. third line'
}

fn test_buffer_gap_buffer_up_moves_cursor_up_successfully() {
	mut buffer := Buffer.new('', .gap_buffer)
	buffer.load_contents_into_gap('1. first line\n2. second line\n3. third line')

	new_pos := buffer.up(Position.new(line: 1, offset: 3), false)?
	assert new_pos == Position.new(line: 0, offset: 3)
	assert buffer.str() == '1. first line\n2. second line\n3. third line'
}

fn test_buffer_legacy_buffer_up_moves_cursor_up_successfully() {
	mut buffer := Buffer.new('', .legacy)
	lines := ['1. first line', '2. second line', '3. third line']
	buffer.lines = lines

	new_pos := buffer.up(Position.new(line: 1, offset: 2), false)?
	assert new_pos == Position.new(line: 0, offset: 2)
	assert buffer.str() == '1. first line\n2. second line\n3. third line'
}

fn test_buffer_line_buffer_up_moves_cursor_up_successfully() {
	mut buffer := Buffer.new('', .line_buffer)
	lines := ['1. first line', '2. second line', '3. third line']
	buffer.load_contents_into_line_buffer(lines)

	new_pos := buffer.up(Position.new(line: 1, offset: 3), false)?
	assert new_pos == Position.new(line: 0, offset: 3)
	assert buffer.str() == '1. first line\n2. second line\n3. third line'
}

fn test_buffer_gap_buffer_up_to_next_blank_line_moves_cursor_up_successfully() {
	mut buffer := Buffer.new('', .gap_buffer)
	buffer.load_contents_into_gap('This is a doc\n1. first line\n\n2. second line\n3. third line\n5. fifth line')

	mut new_pos := buffer.up_to_next_blank_line(Position.new(line: 5, offset: 2))?
	assert new_pos == Position.new(line: 2, offset: 0)

	assert buffer.up_to_next_blank_line(new_pos) == none

	assert buffer.str() == 'This is a doc\n1. first line\n\n2. second line\n3. third line\n5. fifth line'
}

fn test_buffer_gap_buffer_up_to_next_blank_line_moves_cursor_up_successfully_multiple_empty_lines_above() {
	mut buffer := Buffer.new('', .gap_buffer)
	buffer.load_contents_into_gap('This is a doc\n\n1. first line\n2. second line\n3. third line\n\n5. fifth line')

	mut new_pos := buffer.up_to_next_blank_line(Position.new(line: 6, offset: 2))?
	assert new_pos == Position.new(line: 5, offset: 0)

	new_pos = buffer.up_to_next_blank_line(new_pos)?
	assert new_pos == Position.new(line: 1, offset: 0)

	assert buffer.str() == 'This is a doc\n\n1. first line\n2. second line\n3. third line\n\n5. fifth line'
}

fn test_buffer_legacy_buffer_up_to_next_blank_line_moves_cursor_up_successfully() {
	mut buffer := Buffer.new('', .legacy)
	lines := ['This is a doc', '1. first line', '', '2. second line', '3. third line',
		'5. fifth line']
	buffer.lines = lines

	mut new_pos := buffer.up_to_next_blank_line(Position.new(line: 5, offset: 2))?
	assert new_pos == Position.new(line: 2, offset: 0)

	assert buffer.str() == 'This is a doc\n1. first line\n\n2. second line\n3. third line\n5. fifth line'
}

fn test_buffer_legacy_buffer_up_to_next_blank_line_moves_cursor_up_successfully_multiple_empty_lines_above() {
	mut buffer := Buffer.new('', .legacy)
	lines := ['This is a doc', '', '1. first line', '2. second line', '3. third line', '',
		'5. fifth line']
	buffer.lines = lines

	mut new_pos := buffer.up_to_next_blank_line(Position.new(line: 6, offset: 2))?
	assert new_pos == Position.new(line: 5, offset: 0)

	new_pos = buffer.up_to_next_blank_line(new_pos)?
	assert new_pos == Position.new(line: 1, offset: 0)

	assert buffer.str() == 'This is a doc\n\n1. first line\n2. second line\n3. third line\n\n5. fifth line'
}

fn test_buffer_line_buffer_up_to_next_blank_line_moves_cursor_up_successfully() {
	mut buffer := Buffer.new('', .line_buffer)
	lines := ['This is a doc', '1. first line', '', '2. second line', '3. third line',
		'5. fifth line']
	buffer.load_contents_into_line_buffer(lines)

	mut new_pos := buffer.up_to_next_blank_line(Position.new(line: 5, offset: 2))?
	assert new_pos == Position.new(line: 2, offset: 0)

	assert buffer.str() == 'This is a doc\n1. first line\n\n2. second line\n3. third line\n5. fifth line'
}

fn test_buffer_gap_buffer_down_to_next_blank_line_moves_cursor_down_successfully() {
	mut buffer := Buffer.new('', .gap_buffer)
	buffer.load_contents_into_gap('This is a doc\n1. first line\n\n2. second line\n3. third line\n5. fifth line')

	mut new_pos := buffer.down_to_next_blank_line(Position.new(line: 0, offset: 2))?
	assert new_pos == Position.new(line: 2, offset: 0)

	assert buffer.down_to_next_blank_line(new_pos)? == Position.new(line: 5, offset: 0)

	assert buffer.str() == 'This is a doc\n1. first line\n\n2. second line\n3. third line\n5. fifth line'
}

fn test_buffer_gap_buffer_down_to_next_blank_line_moves_cursor_down_successfully_multiple_empty_lines_below() {
	mut buffer := Buffer.new('', .gap_buffer)
	buffer.load_contents_into_gap('This is a doc\n1. first line\n\n2. second line\n3. third line\n\n5. fifth line')

	mut new_pos := buffer.down_to_next_blank_line(Position.new(line: 0, offset: 2))?
	assert new_pos == Position.new(line: 2, offset: 0)

	assert buffer.down_to_next_blank_line(new_pos)? == Position.new(line: 5, offset: 0)

	assert buffer.str() == 'This is a doc\n1. first line\n\n2. second line\n3. third line\n\n5. fifth line'
}

fn test_buffer_legacy_buffer_down_to_next_blank_line_moves_cursor_down_successfully() {
	mut buffer := Buffer.new('', .legacy)
	lines := ['This is a doc', '1. first line', '', '2. second line', '3. third line', '',
		'5. fifth line']
	buffer.lines = lines

	mut new_pos := buffer.down_to_next_blank_line(Position.new(line: 0, offset: 2))?
	assert new_pos == Position.new(line: 2, offset: 0)

	assert buffer.down_to_next_blank_line(new_pos)? == Position.new(line: 5, offset: 0)

	assert buffer.str() == 'This is a doc\n1. first line\n\n2. second line\n3. third line\n\n5. fifth line'
}

fn test_buffer_legacy_buffer_down_to_next_blank_line_moves_cursor_down_successfully_multiple_empty_lines_below() {
	mut buffer := Buffer.new('', .legacy)
	lines := ['This is a doc', '', '1. first line', '2. second line', '3. third line', '',
		'5. fifth line']
	buffer.lines = lines

	mut new_pos := buffer.down_to_next_blank_line(Position.new(line: 0, offset: 2))?
	assert new_pos == Position.new(line: 1, offset: 0)

	assert buffer.down_to_next_blank_line(new_pos)? == Position.new(line: 5, offset: 0)

	assert buffer.str() == 'This is a doc\n\n1. first line\n2. second line\n3. third line\n\n5. fifth line'
}

fn test_buffer_line_buffer_down_to_next_blank_line_moves_cursor_down_successfully() {
	mut buffer := Buffer.new('', .line_buffer)
	lines := ['This is a doc', '1. first line', '', '2. second line', '3. third line',
		'5. fifth line']
	buffer.load_contents_into_line_buffer(lines)

	mut new_pos := buffer.down_to_next_blank_line(Position.new(line: 0, offset: 2))?
	assert new_pos == Position.new(line: 2, offset: 0)

	assert buffer.str() == 'This is a doc\n1. first line\n\n2. second line\n3. third line\n5. fifth line'
}

fn test_buffer_line_buffer_down_to_next_blank_line_moves_cursor_down_successfully_multiple_empty_lines_down() {
	mut buffer := Buffer.new('', .line_buffer)
	lines := ['This is a doc', '', '1. first line', '2. second line', '3. third line', '',
		'5. fifth line']
	buffer.load_contents_into_line_buffer(lines)

	mut new_pos := buffer.down_to_next_blank_line(Position.new(line: 0, offset: 2))?
	assert new_pos == Position.new(line: 1, offset: 0)

	new_pos = buffer.down_to_next_blank_line(new_pos)?
	assert new_pos == Position.new(line: 6, offset: 0)

	assert buffer.str() == 'This is a doc\n\n1. first line\n2. second line\n3. third line\n\n5. fifth line'
}

fn test_buffer_gap_buffer_find_end_of_line() {
	mut buffer := Buffer.new('', .gap_buffer)
	buffer.load_contents_into_gap('1. first line\n2. second line\n3. third line')

	assert buffer.find_end_of_line(Position.new(line: 1, offset: 3))? == Position.new(
		line:   1
		offset: 14
	)
}

fn test_buffer_clamp_cursor_pos_x_within_line_not_insert_mode() {
	mut buffer := Buffer.new('', .legacy)
	lines := ['This is a doc', '', '1. first line', '2. second line', '3. third line', '',
		'5. fifth line']
	buffer.lines = lines

	assert buffer.clamp_cursor_x_pos(Position.new(line: 0, offset: 8), false) == Position.new(
		line:   0
		offset: 8
	)
}

fn test_buffer_clamp_cursor_pos_x_longer_than_line_not_insert_mode() {
	mut buffer := Buffer.new('', .legacy)
	lines := ['This is a doc', '', '1. first line', '2. second line', '3. third line', '',
		'5. fifth line']
	buffer.lines = lines

	assert buffer.clamp_cursor_x_pos(Position.new(line: 0, offset: 20), false) == Position.new(
		line:   0
		offset: 12
	)
}

fn test_buffer_clamp_cursor_pos_x_same_length_of_line_new_not_insert_mode() {
	mut buffer := Buffer.new('', .legacy)
	lines := ['This is a doc', '', '1. first line', '2. second line', '3. third line', '',
		'5. fifth line']
	buffer.lines = lines

	assert buffer.clamp_cursor_x_pos(Position.new(line: 0, offset: 12), true) == Position.new(
		line:   0
		offset: 12
	)
}

fn test_buffer_clamp_cursor_pos_x_within_line_insert_mode() {
	mut buffer := Buffer.new('', .legacy)
	lines := ['This is a doc', '', '1. first line', '2. second line', '3. third line', '',
		'5. fifth line']
	buffer.lines = lines

	assert buffer.clamp_cursor_x_pos(Position.new(line: 0, offset: 8), true) == Position.new(
		line:   0
		offset: 8
	)
}

fn test_buffer_clamp_cursor_pos_x_longer_than_line_insert_mode() {
	mut buffer := Buffer.new('', .legacy)
	lines := ['This is a doc', '', '1. first line', '2. second line', '3. third line', '',
		'5. fifth line']
	buffer.lines = lines

	assert buffer.clamp_cursor_x_pos(Position.new(line: 0, offset: 20), true) == Position.new(
		line:   0
		offset: 13
	)
}

fn test_buffer_clamp_cursor_pos_x_same_length_of_line_insert_mode() {
	mut buffer := Buffer.new('', .legacy)
	lines := ['This is a doc', '', '1. first line', '2. second line', '3. third line', '',
		'5. fifth line']
	buffer.lines = lines

	assert buffer.clamp_cursor_x_pos(Position.new(line: 0, offset: 13), true) == Position.new(
		line:   0
		offset: 13
	)
}
