// Copyright 2026 The Lilly Edtior contributors
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

module buffers

import io

fn mock_reader(content []u8) io.Reader {
	return MockByteReader{
		data:       content
		read_index: 0
	}
}

struct MockByteReader {
	data ?[]u8
mut:
	read_index int
}

fn imin(a int, b int) int {
	return if a < b { a } else { b }
}

fn (mut m MockByteReader) read(mut dest []u8) !int {
	if m.data == ?[]u8(none) { return io.Eof{} }
	data := m.data or { return io.Eof{} }
	if data.len == 0 || m.read_index >= data.len { return io.Eof{} }
	remaining := imin(dest.len, data.len - m.read_index)
	read := copy(mut dest, data[m.read_index..m.read_index + remaining])
	m.read_index += remaining
	return read
}

fn test_text_buffer_init() ! {
	mut reader := mock_reader([])
	TextBuffer.new(mut reader)!
	assert true
}

fn test_text_buffer_get_line_bytes() {
	mut reader := mock_reader('Hello'.bytes())
	mut tb := TextBuffer.new(mut reader)!
	assert tb.get_line_bytes(0)?.bytestr() == 'Hello'
}

fn test_text_buffer_get_line_bytes_of_multiple_lines() ! {
	mut reader := mock_reader('Hello\nWorld'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	assert tb.get_line_bytes(0)?.bytestr() == 'Hello'
	assert tb.get_line_bytes(1)?.bytestr() == 'World'
}

fn test_text_buffer_get_line_bytes_of_multiple_lines_post_backspace() ! {
	mut reader := mock_reader('Hello\nWo'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	assert tb.get_line_bytes(0)?.bytestr() == 'Hello'
	assert tb.get_line_bytes(1)?.bytestr() == 'Wo'

	tb.move_cursor_to_position(1, 2)

	tb.backspace()
	assert tb.get_line_bytes(0)?.bytestr() == 'Hello'
	assert tb.get_line_bytes(1)?.bytestr() == 'W'

	tb.backspace()
	assert tb.get_line_bytes(0)?.bytestr() == 'Hello'
	assert tb.get_line_bytes(1)?.bytestr() == ''

	tb.backspace()
	assert tb.get_line_bytes(0)?.bytestr() == 'Hello'
	assert tb.get_line_bytes(1) == ?[]u8(none)

	tb.backspace()
	assert tb.get_line_bytes(0)?.bytestr() == 'Hell'
	assert tb.get_line_bytes(1) == ?[]u8(none)
}

fn test_text_buffer_insertion_after_cursor_movement() ! {
	mut reader := mock_reader('Hello\n'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	assert tb.get_line_bytes(0)?.bytestr() == 'Hello'
	assert tb.get_line_bytes(1)? == []

	tb.move_cursor_vertical(1)
	tb.insert(u8(`W`))

	assert tb.get_line_bytes(0)?.bytestr() == 'Hello'
	assert tb.get_line_bytes(1)?.bytestr() == 'W'

	tb.move_cursor_left()
	tb.move_cursor_right()
	tb.insert(u8(`o`))

	assert tb.get_line_bytes(0)? == [u8(`H`), `e`, `l`, `l`, `o`]
	assert tb.get_line_bytes(1)? == [u8(`W`), `o`]
}

fn test_text_buffer_backspace() ! {
	mut reader := mock_reader('Hello\n'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	assert tb.get_line_bytes(0)? == [u8(`H`), `e`, `l`, `l`, `o`]
	assert tb.get_line_bytes(1)? == []

	tb.move_cursor_to_position(0, 5)

	tb.backspace()

	// assert tb.get_line_bytes(0)? == [u8(`H`), `e`, `l`, `l`, `o`]
	assert tb.get_line_bytes(0)?.bytestr() == 'Hell'
	assert tb.get_line_bytes(1)? == []

	tb.move_cursor_to_start()
	tb.move_cursor_right()
	tb.delete()
	assert tb.get_line_bytes(0)?.bytestr() == 'Hll'
	assert tb.get_line_bytes(1)? == []
}

fn test_text_buffer_move_cursor_to_start() ! {
	mut reader := mock_reader([]u8{})
	mut tb := TextBuffer.new(mut reader)!
	tb.insert(u8(`H`))
	tb.insert(u8(`e`))
	tb.insert(u8(`l`))
	tb.insert(u8(`l`))
	tb.insert(u8(`o`))
	tb.move_cursor_to_start()
	tb.insert(u8(`>`))
	assert tb.get_line_bytes(0)? == [u8(`>`), `H`, `e`, `l`, `l`, `o`]
}

fn test_text_buffer_blank_lines_after_multiple_inserts_at_start() ! {
	mut reader := mock_reader('hello\nWoRlD<\n😍'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	for _ in 0 .. 3 {
		tb.insert(u8(`\n`))
	}
	assert tb.get_line_bytes(0)? == []
	assert tb.get_line_bytes(1)? == []
	assert tb.get_line_bytes(2)? == []
	assert tb.get_line_bytes(3)? == [u8(`h`), `e`, `l`, `l`, `o`]
}

fn test_text_buffer_cursor_line_and_x_basic() ! {
	mut reader := mock_reader('Hi'.bytes())
	mut tb := TextBuffer.new(mut reader)!
	line, x := tb.cursor_line_and_x()
	assert line == u64(0)
	assert x == u64(0)
}

fn text_text_buffer_cursor_line_and_x_rocket() ! {
	mut reader := mock_reader('🚀r'.bytes())
	mut tb := TextBuffer.new(mut reader)!
	line, x := tb.cursor_line_and_x()
	assert line == u64(0)
	assert x == u64(1)
}

fn test_text_buffer_cursor_line_and_x_ambulance() ! {
	mut reader := mock_reader('🚑️r'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	mut line, mut x := tb.cursor_line_and_x()
	assert line == u64(0)
	assert x == u64(0)

	tb.move_cursor_right()
	line, x = tb.cursor_line_and_x()
	assert line == u64(0)
	assert x == u64(1)

	tb.move_cursor_right()
	line, x = tb.cursor_line_and_x()
	assert line == u64(0)
	assert x == u64(2)

	tb.move_cursor_right()
	line, x = tb.cursor_line_and_x()
	assert line == u64(0)
	assert x == u64(2)
}

fn test_text_buffer_cursor_line_and_x_rocket_and_ambulance() ! {
	mut reader := mock_reader('🚀🚑️r'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	mut line, mut x := tb.cursor_line_and_x()
	assert line == u64(0)
	assert x == u64(0)

	tb.move_cursor_right()
	line, x = tb.cursor_line_and_x()
	assert line == u64(0)
	assert x == u64(1)

	tb.move_cursor_right()
	line, x = tb.cursor_line_and_x()
	assert line == u64(0)
	assert x == u64(2)

	tb.move_cursor_right()
	line, x = tb.cursor_line_and_x()
	assert line == u64(0)
	assert x == u64(3)

	tb.move_cursor_right()
	line, x = tb.cursor_line_and_x()
	assert line == u64(0)
	assert x == u64(3)
}

fn test_text_buffer_move_cursor_left() ! {
	mut reader := mock_reader('hello\nWo'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	mut line, mut x := tb.cursor_line_and_x()
	assert line == u64(0)
	assert x == u64(0)

	tb.move_cursor_to_position(1, 1)

	tb.move_cursor_left()
	line, x = tb.cursor_line_and_x()
	assert line == u64(1)
	assert x == u64(0)
}

fn test_text_buffer_move_cursor_right() ! {
	mut reader := mock_reader('hello\nWo'.bytes())
	mut tb := TextBuffer.new(mut reader)!
	tb.move_cursor_to_start()

	line, x := tb.cursor_line_and_x()
	assert line == u64(0)
	assert x == u64(0)

	tb.move_cursor_right()
	line2, x2 := tb.cursor_line_and_x()
	assert line2 == u64(0)
	assert x2 == u64(1)

	tb.move_cursor_right()
	line3, x3 := tb.cursor_line_and_x()
	assert line3 == u64(0)
	assert x3 == u64(2)

	tb.move_cursor_right()
	line4, x4 := tb.cursor_line_and_x()
	assert line4 == u64(0)
	assert x4 == u64(3)

	tb.move_cursor_right()
	line5, x5 := tb.cursor_line_and_x()
	assert line5 == u64(0)
	assert x5 == u64(4)

	tb.move_cursor_right()
	line6, x6 := tb.cursor_line_and_x()
	assert line6 == u64(0)
	assert x6 == u64(5)
}

fn test_text_buffer_move_cursor_left_stops_at_newline() ! {
	mut reader := mock_reader('ab\ncd'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	tb.move_cursor_to_position(1, 2)
	mut line, mut x := tb.cursor_line_and_x()
	assert line == u64(1)
	assert x == u64(2)

	tb.move_cursor_left()
	tb.move_cursor_left()
	line, x = tb.cursor_line_and_x()
	assert line == u64(1)
	assert x == u64(0)

	tb.move_cursor_left()
	line, x = tb.cursor_line_and_x()
	assert line == u64(1)
	assert x == u64(0)
}

fn test_text_buffer_move_cursor_right_stops_at_newline() ! {
	mut reader := mock_reader('ab\nc'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	tb.move_cursor_to_start()
	tb.move_cursor_right()
	tb.move_cursor_right()
	line, x := tb.cursor_line_and_x()
	assert line == u64(0)
	assert x == u64(2)

	tb.move_cursor_right()
	line2, x2 := tb.cursor_line_and_x()
	assert line2 == u64(0)
	assert x2 == u64(2)
}

fn test_text_buffer_move_cursor_vertically_down() ! {
	mut reader := mock_reader('hello\nWorld'.bytes())
	mut tb := TextBuffer.new(mut reader)!
	tb.move_cursor_to_start()

	tb.move_cursor_right()
	tb.move_cursor_right()
	line, x := tb.cursor_line_and_x()
	assert line == u64(0)
	assert x == u64(2)

	tb.move_cursor_vertical(1)
	line2, x2 := tb.cursor_line_and_x()
	assert line2 == u64(1)
	assert x2 == u64(2)
}

fn test_text_buffer_move_cursor_vertically_up() ! {
	mut reader := mock_reader('hello\nWorld'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	tb.move_cursor_to_position(1, 5)

	line, x := tb.cursor_line_and_x()
	assert line == u64(1)
	assert x == u64(5)

	tb.move_cursor_vertical(-1)
	line2, x2 := tb.cursor_line_and_x()
	assert line2 == u64(0)
	assert x2 == u64(5)
}

fn test_text_buffer_move_cursor_vertical_restores_goal_column_through_short_line() ! {
	mut reader := mock_reader('hello\n\nworld'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	tb.move_cursor_to_position(0, 4)

	// blank line in between clamps x to 0
	tb.move_cursor_vertical(1)
	_, x_blank := tb.cursor_line_and_x()
	assert x_blank == u64(0)

	// but the goal column of 4 is restored once a long-enough line is reached
	tb.move_cursor_vertical(1)
	line, x := tb.cursor_line_and_x()
	assert line == u64(2)
	assert x == u64(4)
}

fn test_text_buffer_move_cursor_vertical_goal_column_resets_on_horizontal_move() ! {
	mut reader := mock_reader('hello\n\nworld'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	tb.move_cursor_to_position(0, 4)
	tb.move_cursor_vertical(1) // clamped to x 0 on the blank line
	tb.move_cursor_left() // no-op (already at x 0), but resets the goal column
	tb.move_cursor_vertical(1)
	line, x := tb.cursor_line_and_x()
	assert line == u64(2)
	assert x == u64(0)
}

fn test_text_buffer_internal_move_cursor_left_preserves_goal_column() ! {
	mut reader := mock_reader('hello\nx\n\nworld'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	tb.move_cursor_to_position(0, 4)

	// lands one grapheme past 'x', the single char on line 1
	tb.move_cursor_vertical(1)
	_, x_landed := tb.cursor_line_and_x()
	assert x_landed == u64(1)

	// simulates an editor's normal-mode "can't sit past the last char" clamp:
	// must not reset the goal column the way a real user h-press would
	tb.internal_move_cursor_left()
	_, x_clamped := tb.cursor_line_and_x()
	assert x_clamped == u64(0)
	assert tb.goal_column == 4

	// blank line still clamps to 0 without disturbing the goal
	tb.move_cursor_vertical(1)
	_, x_blank := tb.cursor_line_and_x()
	assert x_blank == u64(0)

	// original column of 4 is restored once a long-enough line is reached
	tb.move_cursor_vertical(1)
	line, x := tb.cursor_line_and_x()
	assert line == u64(3)
	assert x == u64(4)
}

fn test_text_buffer_move_cursor_to_next_word_start() ! {
	mut reader := mock_reader('hello World\nThis is the second line'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	tb.move_cursor_to_start()

	line, x := tb.cursor_line_and_x()
	assert line == u64(0)
	assert x == u64(0)
	assert tb.line_graphemes(line)[x] == 'h'

	tb.move_cursor_to_next_word_start()

	line2, x2 := tb.cursor_line_and_x()
	assert line2 == u64(0)
	assert x2 == u64(6)
	assert tb.line_graphemes(line2)[x2] == 'W'

	tb.move_cursor_to_next_word_start()

	line3, x3 := tb.cursor_line_and_x()
	assert line3 == u64(1)
	assert x3 == u64(0)
	assert tb.line_graphemes(line3)[x3] == 'T'

	tb.move_cursor_to_next_word_start()

	line4, x4 := tb.cursor_line_and_x()
	assert line4 == u64(1)
	assert x4 == u64(5)
	assert tb.line_graphemes(line4)[x4] == 'i'
}

fn test_text_buffer_move_cursor_to_next_word_start_within_line_containing_graphemes() ! {
	mut reader := mock_reader('🚑️🚑️llo World\nThis is the second line'.bytes())
	mut tb := TextBuffer.new(mut reader)!
	tb.move_cursor_to_start()

	line, x := tb.cursor_line_and_x()
	assert line == u64(0)
	assert x == u64(0)
	assert tb.line_graphemes(line)[x] == '🚑️'

	tb.move_cursor_to_next_word_start()

	line2, x2 := tb.cursor_line_and_x()
	assert line2 == u64(0)
	assert x2 == u64(2)
	assert tb.line_graphemes(line2)[x2] == 'l'

	tb.move_cursor_to_next_word_start()

	line3, x3 := tb.cursor_line_and_x()
	assert line3 == u64(0)
	assert x3 == u64(6)
	assert tb.line_graphemes(line3)[x3] == 'W'

	tb.move_cursor_to_next_word_start()

	line4, x4 := tb.cursor_line_and_x()
	assert line4 == u64(1)
	assert x4 == u64(0)
	assert tb.line_graphemes(line4)[x4] == 'T'
}

fn test_text_buffer_cursor_movement_skips_multibyte_codepoints() ! {
	mut reader := mock_reader('a😍b'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	tb.move_cursor_to_position(0, 1)

	tb.insert(u8(`Z`))
	assert tb.get_line_bytes(0)? == 'aZ😍b'.bytes()

	tb.move_cursor_right()
	tb.insert(u8(`X`))
	assert tb.get_line_bytes(0)? == 'aZ😍Xb'.bytes()
}

fn insert_str(mut tb TextBuffer, s string) {
	for b in s.bytes() {
		tb.insert(b)
	}
}

fn test_text_buffer_delete_range_within_single_line() ! {
	mut reader := mock_reader('Hello, World!'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	tb.delete_range(0, 5, 0, 12)
	assert tb.get_line_bytes(0)? == 'Hello!'.bytes()
}

fn test_text_buffer_delete_range_spanning_multiple_lines() ! {
	mut reader := mock_reader('first line\nsecond line\nthird line'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	tb.delete_range(0, 6, 2, 6)
	assert tb.line_count() == 1
	assert tb.get_line_bytes(0)? == 'first line'.bytes()
}

fn test_text_buffer_delete_range_joins_two_lines() {
	mut reader := mock_reader('foo\nbar'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	// span: end of "foo" through start of "bar" => join lines
	tb.delete_range(0, 3, 1, 0)
	assert tb.line_count() == 1
	assert tb.get_line_bytes(0)? == 'foobar'.bytes()
}

fn test_text_buffer_delete_range_inverted_endpoints() ! {
	mut reader := mock_reader('Hello, World!'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	// same as the within-line case, but with endpoints swapped
	tb.delete_range(0, 12, 0, 5)
	assert tb.get_line_bytes(0)? == 'Hello!'.bytes()
}

fn test_text_buffer_delete_range_clamps_past_end_of_buffer() ! {
	mut reader := mock_reader('abc\ndef'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	tb.delete_range(0, 1, 99, 99)
	assert tb.line_count() == 1
	assert tb.get_line_bytes(0)? == 'a'.bytes()
}

fn test_text_buffer_delete_range_noop_when_endpoints_equal() ! {
	mut reader := mock_reader('unchanged'.bytes())
	mut tb := TextBuffer.new(mut reader)!

	tb.delete_range(0, 4, 0, 4)
	assert tb.get_line_bytes(0)? == 'unchanged'.bytes()
}
