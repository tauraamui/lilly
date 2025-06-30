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
		return ["1. This is a first line", "2. This is a second line", "3. This is a third line"]
	}

	mut buffer := Buffer.new("", .legacy)
	buffer.read_lines(line_reader)!

	assert buffer.lines == ["1. This is a first line", "2. This is a second line", "3. This is a third line"]
}

fn test_buffer_load_from_path_and_iterate() {
	line_reader := fn (path string) ![]string {
		return ["1. This is a first line", "2. This is a second line", "3. This is a third line"]
	}

	mut buffer := Buffer.new("", .legacy)
	buffer.read_lines(line_reader)!

	assert buffer.lines == ["1. This is a first line", "2. This is a second line", "3. This is a third line"]

	mut iteration_count := 0
	for id, line in buffer.line_iterator() {
		iteration_count += 1
		match id {
			0 { assert line == "1. This is a first line" }
			1 { assert line == "2. This is a second line" }
			2 { assert line == "3. This is a third line" }
			else {}
		}
	}

	assert iteration_count == 3
}

fn test_buffer_load_from_path_with_gap_buffer_and_iterate() {
	line_reader := fn (path string) ![]string {
		return ["1. This is a first line", "2. This is a second line", "3. This is a third line"]
	}

	mut buffer := Buffer.new("", .gap_buffer)
	buffer.read_lines(line_reader)!

	mut iteration_count := 0
	for id, line in buffer.line_iterator() {
		iteration_count += 1
		match id {
			0 { assert line == "1. This is a first line" }
			1 { assert line == "2. This is a second line" }
			2 { assert line == "3. This is a third line" }
			else {}
		}
	}

	assert iteration_count == 3
}

fn test_buffer_load_from_path_and_iterate_over_pattern_matches() {
	line_reader := fn (path string) ![]string {
		return ["1. This is a first line", "// TODO(tauraamui) [30/01/25]: this line has a comment to find", "2. This is a second line", "3. This is a third line"]
	}

	mut buffer := Buffer.new("", .legacy)
	buffer.read_lines(line_reader)!

	mut iteration_count := 0
	mut found_match_count := 0
	mut match_iter := buffer.match_iterator("TODO".runes())
	for !match_iter.done() {
		iteration_count += 1
		found_match := match_iter.next() or { continue }
		found_match_count += 1
		assert found_match == Match{
			pos: Pos{ x: 3, y: 1 }
			contents: "TODO(tauraamui) [30/01/25]: this line has a comment to find"
			keyword_len: 4
		}
	}

	assert found_match_count == 1
	assert iteration_count == 5
}

fn test_buffer_load_from_path_and_iterate_over_pattern_matches_excluding_matches_not_within_comment() {
	line_reader := fn (path string) ![]string {
		return [
			"1. This is a first line",
			"// TODO(tauraamui) [30/01/25]: this line has a comment to find",
			"2. This is a second line",
			"3. This line contains TODO but not in a comment",
			"4. This is the fourth line"
		]
	}

	mut buffer := Buffer.new("", .legacy)
	buffer.read_lines(line_reader)!

	mut found_matches := []Match{}

	mut iteration_count := 0
	mut match_iter := buffer.match_iterator("TODO".runes())
	for !match_iter.done() {
		iteration_count += 1
		found_match := match_iter.next() or { continue }
		found_matches << found_match
	}

	assert found_matches.len == 1
	assert found_matches[0] == Match{
		pos: Pos{ x: 3, y: 1 }
		contents: "TODO(tauraamui) [30/01/25]: this line has a comment to find"
		keyword_len: 4
	}
	assert iteration_count == 6
}

fn test_buffer_load_from_path_and_iterate_over_pattern_matches_excluding_matches_within_comment_with_exclusion_prefix() {
	line_reader := fn (path string) ![]string {
		return [
			"1. This is a first line",
			"// -x TODO(tauraamui) [30/01/25]: this line has a comment to find",
			"// TODO(tauraamui) [30/01/25]: comment without exclusion prefix 2. This is a second line",
			"3. This line contains nothing",
			"4. This is the fourth line"
		]
	}

	mut buffer := Buffer.new("", .legacy)
	buffer.read_lines(line_reader)!

	mut found_matches := []Match{}

	mut iteration_count := 0
	mut match_iter := buffer.match_iterator("TODO".runes())
	for !match_iter.done() {
		iteration_count += 1
		found_match := match_iter.next() or { continue }
		found_matches << found_match
	}

	assert found_matches.len == 1
	assert found_matches[0] == Match{
		pos: Pos{ x: 3, y: 2 }
		contents: "TODO(tauraamui) [30/01/25]: comment without exclusion prefix 2. This is a second line"
		keyword_len: 4
	}
	assert iteration_count == 6
}


fn test_buffer_load_from_path_with_gap_buffer_and_iterate_over_pattern_matches() {
	line_reader := fn (path string) ![]string {
		return ["1. This is a first line", "// TODO(tauraamui) [30/01/25]: this line has a comment to find", "2. This is a second line", "3. This is a third line"]
	}

	mut buffer := Buffer.new("", .gap_buffer)
	buffer.read_lines(line_reader)!

	mut iteration_count := 0
	mut found_match_count := 0
	mut match_iter := buffer.match_iterator("TODO".runes())
	for !match_iter.done() {
		iteration_count += 1
		found_match := match_iter.next() or { continue }
		found_match_count += 1
		assert found_match == Match{
			pos: Pos{ x: 3, y: 1 }
			contents: "TODO"
		}
	}

	assert found_match_count == 1
	assert iteration_count == 2
}

fn test_buffer_gap_buffer_insert_text() {
	mut buffer := Buffer.new("", .gap_buffer)
	buffer.c_buffer = GapBuffer.new("")

	for r in "Some text to insert!".runes() { buffer.c_buffer.insert(r) }

	assert buffer.str() == "Some text to insert!"
}

fn test_buffer_gap_buffer_enter_inserts_newline_line() {
	mut buffer := Buffer.new("", .gap_buffer)
	buffer.c_buffer = GapBuffer.new("1. first line\n2. second line\n3. third line")
	buffer.enter(Pos{ x: 4, y: 0 })
	assert buffer.str() == "1. f\nirst line\n2. second line\n3. third line"
}

fn test_buffer_legacy_buffer_enter_inserts_newline_line() {
	mut buffer := Buffer.new("", .legacy)
	buffer.lines = ["1. first line", "2. second line", "3. third line"]
	buffer.enter(Pos{ x: 4, y: 0 })
	assert buffer.str() == "1. f\nirst line\n2. second line\n3. third line"
}

fn test_buffer_gap_buffer_x_deletes_char_from_line() {
	mut buffer := Buffer.new("", .gap_buffer)
	buffer.c_buffer = GapBuffer.new("1. first line\n2. second line\n3. third line")

	mut new_pos := buffer.x(Pos{ x: 4, y: 0 })?
	assert new_pos == Pos{ x: 4, y: 0 }
	assert buffer.str() == "1. frst line\n2. second line\n3. third line"

	new_pos = buffer.x(new_pos)?
	assert new_pos == Pos{ x: 4, y: 0 }
	assert buffer.str() == "1. fst line\n2. second line\n3. third line"
}

fn test_buffer_legacy_buffer_x_deletes_char_from_line() {
	mut buffer := Buffer.new("", .legacy)
	buffer.lines = ["1. first line", "2. second line", "3. third line"]

	mut new_pos := buffer.x(Pos{ x: 4, y: 0 })?
	assert new_pos == Pos{ x: 4, y: 0 }
	assert buffer.str() == "1. frst line\n2. second line\n3. third line"

	new_pos = buffer.x(new_pos)?
	assert new_pos == Pos{ x: 4, y: 0 }
	assert buffer.str() == "1. fst line\n2. second line\n3. third line"
}

fn test_buffer_line_buffer_x_deletes_char_from_line() {
	mut buffer := Buffer.new("", .line_buffer)
	lines := ["1. first line", "2. second line", "3. third line"]
	buffer.load_contents_into_line_buffer(lines)

	mut new_pos := buffer.x(Pos{ x: 4, y: 0 })?
	assert new_pos == Pos{ x: 4, y: 0 }
	assert buffer.str() == "1. frst line\n2. second line\n3. third line"

	new_pos = buffer.x(new_pos)?
	assert new_pos == Pos{ x: 4, y: 0 }
	assert buffer.str() == "1. fst line\n2. second line\n3. third line"
}

fn test_buffer_gap_buffer_delete_deletes_char_from_line() {
	mut buffer := Buffer.new("", .gap_buffer)
	buffer.c_buffer = GapBuffer.new("1. first line\n2. second line\n3. third line")

	assert buffer.delete(false)
	assert buffer.str() == ". first line\n2. second line\n3. third line"
}

fn test_buffer_legacy_buffer_delete_does_nothing() {
	mut buffer := Buffer.new("", .legacy)
	lines := ["1. first line", "2. second line", "3. third line"]
	buffer.lines = lines

	assert buffer.delete(false) == false
	assert buffer.str() == "1. first line\n2. second line\n3. third line"
}

fn test_buffer_line_buffer_delete_does_nothing() {
	mut buffer := Buffer.new("", .line_buffer)
	lines := ["1. first line", "2. second line", "3. third line"]
	buffer.load_contents_into_line_buffer(lines)

	assert buffer.delete(false) == false
	assert buffer.str() == "1. first line\n2. second line\n3. third line"
}

