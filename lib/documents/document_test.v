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

module documents

import lib.buffers
import lib.documents.cursor
import os

fn test_char_scanner() {
	mut c_scanner := CharScanner{
		data: 'This is some test content'.runes()
	}

	assert c_scanner.next_diff()? == ScanResult{
		index:      4
		cchar:      ` `
		cchar_str:  ' '
		start_type: .alpha_num
		next_type:  .whitespace
	}
	assert c_scanner.next_diff()? == ScanResult{
		index:      5
		cchar:      `i`
		cchar_str:  'i'
		start_type: .whitespace
		next_type:  .alpha_num
	}
	assert c_scanner.next_diff()? == ScanResult{
		index:      7
		cchar:      ` `
		cchar_str:  ' '
		start_type: .alpha_num
		next_type:  .whitespace
	}
}

fn test_char_scanner_prev() {
	mut c_scanner := CharScanner{
		data:       'This is some test content'.runes()
		last_index: 15
	}

	assert c_scanner.prev_diff()? == ScanResult{
		index:      12
		cchar:      ` `
		cchar_str:  ' '
		start_type: .alpha_num
		next_type:  .whitespace
		pre_diff:   PreDiffChar{
			index:     13
			cchar:     `t`
			cchar_str: 't'
			c_type:    .alpha_num
		}
	}
}

const mock_content = 'This is the.first line
This is the second line.'

fn test_document_move_cursor_left() {
	d := Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: mock_content.runes())
	}

	assert d.move_cursor_left(cursor.Pos.new(8, 0)) == cursor.Pos.new(7, 0)
}

fn test_document_move_cursor_down() {
	d := Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: mock_content.runes())
	}

	assert d.move_cursor_down(cursor.Pos.new(0, 0), .normal) == cursor.Pos.new(0, 1)
}

fn test_document_move_cursor_down_jumps_to_largest_x() {
	d := Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: mock_content.runes())
	}

	assert d.move_cursor_down(cursor.Pos.new_z(0, 0, 11), .normal) == cursor.Pos.new_z(11, 1, 11)
}

fn test_document_move_cursor_up() {
	d := Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: mock_content.runes())
	}

	assert d.move_cursor_up(cursor.Pos.new(8, 1), .normal) == cursor.Pos.new(8, 0)
}

fn test_document_move_cursor_up_jumps_to_largest_x() {
	d := Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: mock_content.runes())
	}

	assert d.move_cursor_up(cursor.Pos.new_z(8, 1, 11), .normal) == cursor.Pos.new_z(11, 0, 11)
}

fn test_document_move_cursor_right() {
	d := Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: mock_content.runes())
	}

	assert d.move_cursor_right(cursor.Pos.new(8, 1), .normal) == cursor.Pos.new(9, 1)
}

fn test_scan_to_next_word_start() {
	gb := buffers.GapBuffer.new(content: mock_content.runes())

	mut next_word_start_pos := scan_to_next_word_start(gb, cursor.Pos.new(0, 0), 0)?
	assert next_word_start_pos == cursor.Pos.new(5, 0)
	assert get_char_at(gb, next_word_start_pos) == 'i'

	next_word_start_pos = scan_to_next_word_start(gb, next_word_start_pos, 0)?
	assert next_word_start_pos == cursor.Pos.new(8, 0)
	assert get_char_at(gb, next_word_start_pos) == 't'

	next_word_start_pos = scan_to_next_word_start(gb, next_word_start_pos, 0)?
	assert next_word_start_pos == cursor.Pos.new(11, 0)
	assert get_char_at(gb, next_word_start_pos) == '.'

	next_word_start_pos = scan_to_next_word_start(gb, next_word_start_pos, 0)?
	assert next_word_start_pos == cursor.Pos.new(12, 0)
	assert get_char_at(gb, next_word_start_pos) == 'f'
}

fn test_scan_to_previous_word_start() {
	gb := buffers.GapBuffer.new(content: mock_content.runes())
	mut previous_word_start_pos :=
		scan_to_previous_word_start(gb, cursor.Pos.new(15, 0), 0)? // cursor starting on 's' in word 'first'
	assert previous_word_start_pos == cursor.Pos.new(12, 0)
	assert get_char_at(gb, previous_word_start_pos) == 'f'

	previous_word_start_pos =
		scan_to_previous_word_start(gb, previous_word_start_pos, 0)? // cursor should now be on 't' of word 'the'
	assert previous_word_start_pos == cursor.Pos.new(11, 0)
	assert get_char_at(gb, previous_word_start_pos) == '.'

	previous_word_start_pos =
		scan_to_previous_word_start(gb, previous_word_start_pos, 0)? // cursor should now be on 't' of word 'the'
	assert previous_word_start_pos == cursor.Pos.new(8, 0)
	assert get_char_at(gb, previous_word_start_pos) == 't'

	previous_word_start_pos =
		scan_to_previous_word_start(gb, previous_word_start_pos, 0)? // cursor should now be on 't' of word 'the'
	assert previous_word_start_pos == cursor.Pos.new(5, 0)
	assert get_char_at(gb, previous_word_start_pos) == 'i'
}

fn get_char_at(data buffers.GapBuffer, pos cursor.Pos) string {
	return [data.get_char_at(y: pos.y, x: pos.x) or { '?'.runes()[0] }].string()
}

fn new_controller_with_content(content string) (Controller, int) {
	id := 0
	mut ctrl := Controller{}
	ctrl.docs[id] = Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: content.runes())
	}
	return ctrl, id
}

// ─── Controller-level tests ───

fn test_controller_move_cursor_down_by() {
	ctrl, id := new_controller_with_content(mock_multiline_content_with_blanks)
	assert ctrl.move_cursor_down_by(id, cursor.Pos.new(0, 0), 3, .normal) == cursor.Pos.new(0, 3)
}

fn test_controller_move_cursor_down_by_stops_at_last_line() {
	ctrl, id := new_controller_with_content(mock_content)
	// mock_content has 2 lines (0 and 1), moving down by 10 should stop at line 1
	assert ctrl.move_cursor_down_by(id, cursor.Pos.new(0, 0), 10, .normal) == cursor.Pos.new(0, 1)
}

fn test_controller_move_cursor_down_by_zero() {
	ctrl, id := new_controller_with_content(mock_content)
	assert ctrl.move_cursor_down_by(id, cursor.Pos.new(0, 0), 0, .normal) == cursor.Pos.new(0, 0)
}

fn test_controller_move_cursor_up_by() {
	ctrl, id := new_controller_with_content(mock_multiline_content_with_blanks)
	assert ctrl.move_cursor_up_by(id, cursor.Pos.new(0, 5), 3, .normal) == cursor.Pos.new(0, 2)
}

fn test_controller_move_cursor_up_by_stops_at_first_line() {
	ctrl, id := new_controller_with_content(mock_content)
	assert ctrl.move_cursor_up_by(id, cursor.Pos.new(0, 1), 10, .normal) == cursor.Pos.new(0, 0)
}

fn test_controller_move_cursor_up_by_zero() {
	ctrl, id := new_controller_with_content(mock_content)
	assert ctrl.move_cursor_up_by(id, cursor.Pos.new(5, 1), 0, .normal) == cursor.Pos.new(5, 1)
}

fn test_controller_move_cursor_up_by_already_at_top() {
	ctrl, id := new_controller_with_content(mock_content)
	assert ctrl.move_cursor_up_by(id, cursor.Pos.new(0, 0), 3, .normal) == cursor.Pos.new(0, 0)
}

fn test_controller_move_cursor_down_by_already_at_bottom() {
	ctrl, id := new_controller_with_content(mock_content)
	assert ctrl.move_cursor_down_by(id, cursor.Pos.new(0, 1), 5, .normal) == cursor.Pos.new(0, 1)
}

fn test_controller_move_cursor_down_by_preserves_x() {
	ctrl, id := new_controller_with_content(mock_multiline_content_with_blanks)
	pos := ctrl.move_cursor_down_by(id, cursor.Pos.new(8, 0), 2, .normal)
	assert pos == cursor.Pos.new(0, 2)
	assert ctrl.move_cursor_down_by(id, pos, 2, .normal) == cursor.Pos.new(8, 4)
}

fn test_controller_move_cursor_up_by_preserves_x() {
	ctrl, id := new_controller_with_content(mock_multiline_content_with_blanks)
	pos := ctrl.move_cursor_up_by(id, cursor.Pos.new(8, 3), 1, .normal)
	// line 2 is blank, so x clamps; but largest_x should restore on line 1
	assert pos.y == 2
}

fn test_controller_move_cursor_down() {
	ctrl, id := new_controller_with_content(mock_content)
	assert ctrl.move_cursor_down(id, cursor.Pos.new(0, 0), .normal) == cursor.Pos.new(0, 1)
}

fn test_controller_move_cursor_up() {
	ctrl, id := new_controller_with_content(mock_content)
	assert ctrl.move_cursor_up(id, cursor.Pos.new(0, 1), .normal) == cursor.Pos.new(0, 0)
}

fn test_controller_move_cursor_left() {
	ctrl, id := new_controller_with_content(mock_content)
	assert ctrl.move_cursor_left(id, cursor.Pos.new(5, 0)) == cursor.Pos.new(4, 0)
}

fn test_controller_move_cursor_right() {
	ctrl, id := new_controller_with_content(mock_content)
	assert ctrl.move_cursor_right(id, cursor.Pos.new(0, 0), .normal) == cursor.Pos.new(1, 0)
}

fn test_controller_write_document_preserves_permissions() ? {
	file_path := os.join_path(os.temp_dir(), 'lilly_exec_perm_test_' + os.getpid().str() + '.vsh')
	if os.exists(file_path) {
		os.rm(file_path)!
	}
	os.write_file(file_path, '#!/bin/bash\necho hello\n')!
	defer {
		os.rm(file_path) or {}
	}
	expected_mode := 0o755
	os.chmod(file_path, expected_mode)!
	mut ctrl := Controller.new()
	doc_id := ctrl.open_document(file_path)!
	ctrl.docs[doc_id].data.set_content('#!/bin/bash\necho goodbye'.runes())
	ctrl.write_document(doc_id)!
	stat := os.stat(file_path)!
	assert int(stat.mode) & 0o7777 == expected_mode
}

fn test_controller_insert_newline_between_braces_positions_cursor_at_line_start() {
	mut ctrl, id := new_controller_with_content('{}')

	mut pos := cursor.Pos.new(1, 0)
	ctrl.prepare_for_insertion_at(id, pos) or { panic(err) }
	pos = ctrl.insert_newline(id, pos)

	assert pos == cursor.Pos.new(0, 1)
	assert ctrl.get_line_at(id, 0) or { panic(err) } == '{'
	assert ctrl.get_line_at(id, 1) or { panic(err) } == '}'
}

fn test_controller_move_cursor_to_line_end() {
	ctrl, id := new_controller_with_content(mock_content)
	// mock_content first line: 'This is the.first line' (22 chars, last index 21)
	pos := ctrl.move_cursor_to_line_end(id, cursor.Pos.new(0, 0), .normal)
	assert pos.y == 0
	assert pos.x == 21
}

fn test_controller_move_cursor_to_line_start() {
	ctrl, id := new_controller_with_content(mock_content)
	pos := ctrl.move_cursor_to_line_start(id, cursor.Pos.new(21, 0))
	assert pos.y == 0
	assert pos.x == 0
}

fn test_controller_move_cursor_to_text_start() {
	ctrl, id := new_controller_with_content(mock_content)
	pos := ctrl.move_cursor_to_text_start(id, cursor.Pos.new(21, 0))
	assert pos.y == 0
	assert pos.x == 0
}

fn test_controller_move_cursor_to_text_start_on_line_with_padding() {
	ctrl, id := new_controller_with_content(mock_content + '\n\t\t\tThis is the third line')
	pos := ctrl.move_cursor_to_text_start(id, cursor.Pos.new(10, 2))
	assert pos.y == 2
	assert pos.x == 3
}

fn test_controller_move_cursor_to_next_blank_line() {
	ctrl, id := new_controller_with_content(mock_multiline_content_with_blanks)
	pos := ctrl.move_cursor_to_next_blank_line(id, cursor.Pos.new(0, 0))
	assert pos == cursor.Pos.new(0, 2)
	assert ctrl.move_cursor_to_next_blank_line(id, pos) == cursor.Pos.new(0, 5)
}

fn test_controller_move_cursor_to_previous_blank_line() {
	ctrl, id := new_controller_with_content(mock_multiline_content_with_blanks)
	pos := ctrl.move_cursor_to_previous_blank_line(id, cursor.Pos.new(0, 9))
	assert pos == cursor.Pos.new(0, 8)
	assert ctrl.move_cursor_to_previous_blank_line(id, pos) == cursor.Pos.new(0, 5)
}

fn test_controller_move_cursor_down_by_then_up_by_roundtrip() {
	ctrl, id := new_controller_with_content(mock_multiline_content_with_blanks)
	pos := ctrl.move_cursor_down_by(id, cursor.Pos.new(0, 0), 5, .normal)
	assert pos == cursor.Pos.new(0, 5)
	assert ctrl.move_cursor_up_by(id, pos, 5, .normal) == cursor.Pos.new(0, 0)
}

fn test_controller_move_cursor_down_by_single_line_doc() {
	ctrl, id := new_controller_with_content('only one line')
	assert ctrl.move_cursor_down_by(id, cursor.Pos.new(0, 0), 3, .normal) == cursor.Pos.new(0, 0)
}

fn test_controller_move_cursor_up_by_single_line_doc() {
	ctrl, id := new_controller_with_content('only one line')
	assert ctrl.move_cursor_up_by(id, cursor.Pos.new(0, 0), 3, .normal) == cursor.Pos.new(0, 0)
}

fn test_doc_move_cursor_to_next_word_start() {
	mut d := Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: mock_content.runes())
	}

	assert d.move_cursor_to_next_word_start(cursor.Pos.new(3, 0)) == cursor.Pos.new(5, 0)
	assert d.move_cursor_to_next_word_start(cursor.Pos.new(5, 0)) == cursor.Pos.new(8, 0)
	assert d.move_cursor_to_next_word_start(cursor.Pos.new(8, 0)) == cursor.Pos.new(11, 0)
	assert d.move_cursor_to_next_word_start(cursor.Pos.new(11, 0)) == cursor.Pos.new(12, 0)
	assert d.move_cursor_to_next_word_start(cursor.Pos.new(12, 0)) == cursor.Pos.new(18, 0)
	assert d.move_cursor_to_next_word_start(cursor.Pos.new(18, 0)) == cursor.Pos.new(0, 1)

	assert d.move_cursor_to_next_word_start(cursor.Pos.new(0, 1)) == cursor.Pos.new(5, 1)
	assert d.move_cursor_to_next_word_start(cursor.Pos.new(5, 1)) == cursor.Pos.new(8, 1)
	assert d.move_cursor_to_next_word_start(cursor.Pos.new(8, 1)) == cursor.Pos.new(12, 1)
	assert d.move_cursor_to_next_word_start(cursor.Pos.new(12, 1)) == cursor.Pos.new(19, 1)
	assert d.move_cursor_to_next_word_start(cursor.Pos.new(19, 1)) == cursor.Pos.new(23, 1)
}

fn test_read_file_trim_eol_lf() ? {
	file_path := os.join_path(os.temp_dir(), 'test_LF.txt')
	os.write_file(file_path, 'hello\n')!

	content, eol := read_file_trim_eol(file_path)!

	assert content == 'hello'
	assert eol == '\n'

	os.rm(file_path)!
}

fn test_read_file_trim_eol_lf_with_double_lf() ? {
	file_path := os.join_path(os.temp_dir(), 'test_LF.txt')
	os.write_file(file_path, 'hello\n\n')!

	content, eol := read_file_trim_eol(file_path)!

	assert content == 'hello\n'
	assert eol == '\n'

	os.rm(file_path)!
}

fn test_read_file_trim_eol_crlf() ? {
	file_path := os.join_path(os.temp_dir(), 'test_CRLF.txt')
	os.write_file(file_path, 'hello\r\n')!

	content, eol := read_file_trim_eol(file_path)!

	assert content == 'hello'
	assert eol == '\r\n'

	os.rm(file_path)!
}

fn test_read_file_trim_eol_crlf_mix_of_char_twixt() ? {
	file_path := os.join_path(os.temp_dir(), 'test_CRLF.txt')
	os.write_file(file_path, 'hello\rx\n')!

	content, eol := read_file_trim_eol(file_path)!

	assert content == 'hello\rx'
	assert eol == '\n'

	os.rm(file_path)!
}

fn test_read_file_trim_eol_crlf_reversed() ? {
	file_path := os.join_path(os.temp_dir(), 'test_CRLF.txt')
	os.write_file(file_path, 'hello\n\r')!

	content, eol := read_file_trim_eol(file_path)!

	assert content == 'hello\n\r'
	assert eol == ''

	os.rm(file_path)!
}

fn test_doc_move_cursor_to_previous_word_start() {
	mut d := Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: mock_content.runes())
	}

	assert d.move_cursor_to_previous_word_start(cursor.Pos.new(15, 0)) == cursor.Pos.new(12, 0)
	assert d.move_cursor_to_previous_word_start(cursor.Pos.new(12, 0)) == cursor.Pos.new(11, 0)
	assert d.move_cursor_to_previous_word_start(cursor.Pos.new(11, 0)) == cursor.Pos.new(8, 0)
	assert d.move_cursor_to_previous_word_start(cursor.Pos.new(8, 0)) == cursor.Pos.new(5, 0)
	assert d.move_cursor_to_previous_word_start(cursor.Pos.new(5, 0)) == cursor.Pos.new(0, 0)
	assert d.move_cursor_to_previous_word_start(cursor.Pos.new(0, 0)) == cursor.Pos.new(0, 0)

	assert d.move_cursor_to_previous_word_start(cursor.Pos.new(16, 1)) == cursor.Pos.new(12, 1)
	assert d.move_cursor_to_previous_word_start(cursor.Pos.new(12, 1)) == cursor.Pos.new(8, 1)
	assert d.move_cursor_to_previous_word_start(cursor.Pos.new(8, 1)) == cursor.Pos.new(5, 1)
	assert d.move_cursor_to_previous_word_start(cursor.Pos.new(5, 1)) == cursor.Pos.new(0, 1)
	assert d.move_cursor_to_previous_word_start(cursor.Pos.new(0, 1)) == cursor.Pos.new(18, 0)
}

const mock_punct_content = 'abc() {'

fn test_doc_move_cursor_to_previous_word_start_with_punct() {
	mut d := Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: mock_punct_content.runes())
	}

	// backward from { should land on start of ()
	assert d.move_cursor_to_previous_word_start(cursor.Pos.new(6, 0)) == cursor.Pos.new(3, 0)
	// backward from () should land on start of abc
	assert d.move_cursor_to_previous_word_start(cursor.Pos.new(3, 0)) == cursor.Pos.new(0, 0)
}

fn test_doc_move_cursor_to_next_word_start_with_punct() {
	mut d := Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: mock_punct_content.runes())
	}

	// forward from abc should land on (
	assert d.move_cursor_to_next_word_start(cursor.Pos.new(0, 0)) == cursor.Pos.new(3, 0)
	// forward from () should land on {
	assert d.move_cursor_to_next_word_start(cursor.Pos.new(3, 0)) == cursor.Pos.new(6, 0)
}

const mock_crossline_punct_content = 'struct EditorModel {
	id int'

fn test_doc_move_cursor_to_previous_word_start_cross_line_lands_on_brace() {
	mut d := Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: mock_crossline_punct_content.runes())
	}

	// backward from start of 'id' on line 1 should land on { on line 0
	assert d.move_cursor_to_previous_word_start(cursor.Pos.new(1, 1)) == cursor.Pos.new(19, 0)
	// backward from { should land on start of EditorModel
	assert d.move_cursor_to_previous_word_start(cursor.Pos.new(19, 0)) == cursor.Pos.new(7, 0)
	// backward from EditorModel should land on start of struct
	assert d.move_cursor_to_previous_word_start(cursor.Pos.new(7, 0)) == cursor.Pos.new(0, 0)
}

fn test_doc_move_cursor_to_next_word_end() {
	mut d := Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: mock_content.runes())
	}

	// 'This is the.first line'
	// e from 'T' of 'This' → 's' (end of 'This')
	assert d.move_cursor_to_next_word_end(cursor.Pos.new(0, 0)) == cursor.Pos.new(3, 0)
	// e from 's' of 'This' → 's' (end of 'is')
	assert d.move_cursor_to_next_word_end(cursor.Pos.new(3, 0)) == cursor.Pos.new(6, 0)
	// e from 's' of 'is' → 'e' (end of 'the')
	assert d.move_cursor_to_next_word_end(cursor.Pos.new(6, 0)) == cursor.Pos.new(10, 0)
	// e from 'e' of 'the' → '.' (end of '.')
	assert d.move_cursor_to_next_word_end(cursor.Pos.new(10, 0)) == cursor.Pos.new(11, 0)
	// e from '.' → 't' (end of 'first')
	assert d.move_cursor_to_next_word_end(cursor.Pos.new(11, 0)) == cursor.Pos.new(16, 0)
	// e from 't' of 'first' → 'e' (end of 'line')
	assert d.move_cursor_to_next_word_end(cursor.Pos.new(16, 0)) == cursor.Pos.new(21, 0)
	// e from 'e' of 'line' (end of line 0) → crosses to line 1
	// 'This is the second line.'
	assert d.move_cursor_to_next_word_end(cursor.Pos.new(21, 0)) == cursor.Pos.new(3, 1)
}

fn test_doc_move_cursor_to_next_word_end_with_punct() {
	mut d := Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: mock_punct_content.runes())
	}

	// 'abc() {'
	// e from 'a' → 'c' (end of 'abc')
	assert d.move_cursor_to_next_word_end(cursor.Pos.new(0, 0)) == cursor.Pos.new(2, 0)
	// e from 'c' → ')' (end of '()')
	assert d.move_cursor_to_next_word_end(cursor.Pos.new(2, 0)) == cursor.Pos.new(4, 0)
	// e from ')' → '{' (end of '{')
	assert d.move_cursor_to_next_word_end(cursor.Pos.new(4, 0)) == cursor.Pos.new(6, 0)
}

fn test_doc_move_cursor_to_previous_word_end() {
	mut d := Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: mock_content.runes())
	}

	// 'This is the.first line'
	// ge from 'e' of 'line' → 't' (end of 'first')
	assert d.move_cursor_to_previous_word_end(cursor.Pos.new(21, 0)) == cursor.Pos.new(16, 0)
	// ge from 't' of 'first' → '.' (end of '.')
	assert d.move_cursor_to_previous_word_end(cursor.Pos.new(16, 0)) == cursor.Pos.new(11, 0)
	// ge from '.' → 'e' (end of 'the')
	assert d.move_cursor_to_previous_word_end(cursor.Pos.new(11, 0)) == cursor.Pos.new(10, 0)
	// ge from 'e' of 'the' → 's' (end of 'is')
	assert d.move_cursor_to_previous_word_end(cursor.Pos.new(10, 0)) == cursor.Pos.new(6, 0)
	// ge from 's' of 'is' → 's' (end of 'This')
	assert d.move_cursor_to_previous_word_end(cursor.Pos.new(6, 0)) == cursor.Pos.new(3, 0)
	// ge from 's' of 'This' at start — stays put
	assert d.move_cursor_to_previous_word_end(cursor.Pos.new(3, 0)) == cursor.Pos.new(3, 0)
}

fn test_doc_move_cursor_to_previous_word_end_cross_line() {
	mut d := Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: mock_content.runes())
	}

	// 'This is the.first line\nThis is the second line.'
	// ge from 'T' of 'This' on line 1 → 'e' (end of 'line' on line 0)
	assert d.move_cursor_to_previous_word_end(cursor.Pos.new(0, 1)) == cursor.Pos.new(21, 0)
}

fn test_doc_move_cursor_to_next_big_word_start() {
	// mock_content = 'This is the.first line\nThis is the second line.'
	mut d := Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: mock_content.runes())
	}

	// W skips over non-whitespace (the.first is one WORD)
	assert d.move_cursor_to_next_big_word_start(cursor.Pos.new(0, 0)) == cursor.Pos.new(5, 0)
	assert d.move_cursor_to_next_big_word_start(cursor.Pos.new(5, 0)) == cursor.Pos.new(8, 0)
	assert d.move_cursor_to_next_big_word_start(cursor.Pos.new(8, 0)) == cursor.Pos.new(18, 0)
	assert d.move_cursor_to_next_big_word_start(cursor.Pos.new(18, 0)) == cursor.Pos.new(0, 1)
}

fn test_doc_move_cursor_to_next_big_word_start_with_punct() {
	// mock_punct_content = 'abc() {'
	mut d := Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: mock_punct_content.runes())
	}

	// W from 'a': abc() is one WORD, skip to {
	assert d.move_cursor_to_next_big_word_start(cursor.Pos.new(0, 0)) == cursor.Pos.new(6, 0)
}

const mock_multiline_content_with_blanks = 'This is the first line.
This is the second line.

This is the forth line.
This is the fifth line.

This is the seventh line.
This is the eighth line.

This is the tenth line.'

fn test_doc_move_cursor_to_next_blank_line() {
	mut d := Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: mock_multiline_content_with_blanks.runes())
	}

	assert d.move_cursor_to_next_blank_line(cursor.Pos.new(8, 0)) == cursor.Pos.new(0, 2)
	assert d.move_cursor_to_next_blank_line(cursor.Pos.new(0, 2)) == cursor.Pos.new(0, 5)
	assert d.move_cursor_to_next_blank_line(cursor.Pos.new(0, 5)) == cursor.Pos.new(0, 8)
	assert d.move_cursor_to_next_blank_line(cursor.Pos.new(0, 8)) == cursor.Pos.new(0, 9)
	assert d.move_cursor_to_next_blank_line(cursor.Pos.new(0, 9)) == cursor.Pos.new(0, 9)
}

fn test_doc_move_cursor_to_previous_blank_line() {
	mut d := Document{
		file_path: ''
		data:      buffers.GapBuffer.new(content: mock_multiline_content_with_blanks.runes())
	}

	assert d.move_cursor_to_previous_blank_line(cursor.Pos.new(8, 9)) == cursor.Pos.new(0, 8)
	assert d.move_cursor_to_previous_blank_line(cursor.Pos.new(0, 8)) == cursor.Pos.new(0, 5)
	assert d.move_cursor_to_previous_blank_line(cursor.Pos.new(0, 5)) == cursor.Pos.new(0, 2)
	assert d.move_cursor_to_previous_blank_line(cursor.Pos.new(0, 2)) == cursor.Pos.new(0, 0)
	assert d.move_cursor_to_previous_blank_line(cursor.Pos.new(0, 0)) == cursor.Pos.new(0, 0)
}
