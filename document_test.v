module documents

import lib.buffers
import lib.documents.cursor

fn test_char_scanner() {
	mut c_scanner := CharScanner{
		data: 'This is some test content'.runes()
	}

	assert c_scanner.next_diff()? == ScanResult{ index: 4, cchar: ` `, cchar_str: ' ', start_type: .alpha_num, next_type: .whitespace }
	assert c_scanner.next_diff()? == ScanResult{ index: 5, cchar: `i`, cchar_str: 'i', start_type: .whitespace, next_type: .alpha_num }
	assert c_scanner.next_diff()? == ScanResult{ index: 7, cchar: ` `, cchar_str: ' ', start_type: .alpha_num, next_type: .whitespace }
}

fn test_char_scanner_prev() {
	mut c_scanner := CharScanner{
		data: 'This is some test content'.runes()
		last_index: 15
	}

	assert c_scanner.prev_diff()? == ScanResult{
		index: 12, cchar: ` `, cchar_str: ' ', start_type: .alpha_num,
		next_type: .whitespace,
		pre_diff: PreDiffChar{
			index: 13, cchar: `t`, cchar_str: 't', c_type: .alpha_num
		}
	}
}

const mock_content := 'This is the.first line
This is the second line.'

fn test_document_move_cursor_left() {
	d := Document{
		file_path: ''
		data: buffers.GapBuffer.new(content: mock_content.runes())
	}

	assert d.move_cursor_left(cursor.Pos.new(8, 0), .normal) == cursor.Pos.new(7, 0)
}

fn test_document_move_cursor_down() {
	d := Document{
		file_path: ''
		data: buffers.GapBuffer.new(content: mock_content.runes())
	}

	assert d.move_cursor_down(cursor.Pos.new(0, 0), .normal) == cursor.Pos.new(0, 1)
}

fn test_document_move_cursor_down_jumps_to_largest_x() {
	d := Document{
		file_path: ''
		data: buffers.GapBuffer.new(content: mock_content.runes())
	}

	assert d.move_cursor_down(cursor.Pos.new_z(0, 0, 11), .normal) == cursor.Pos.new_z(11, 1, 11)
}

fn test_document_move_cursor_up() {
	d := Document{
		file_path: ''
		data: buffers.GapBuffer.new(content: mock_content.runes())
	}

	assert d.move_cursor_up(cursor.Pos.new(8, 1), .normal) == cursor.Pos.new(8, 0)
}

fn test_document_move_cursor_up_jumps_to_largest_x() {
	d := Document{
		file_path: ''
		data: buffers.GapBuffer.new(content: mock_content.runes())
	}

	assert d.move_cursor_up(cursor.Pos.new_z(8, 1, 11), .normal) == cursor.Pos.new_z(11, 0, 11)
}

fn test_document_move_cursor_right() {
	d := Document{
		file_path: ''
		data: buffers.GapBuffer.new(content: mock_content.runes())
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
	mut previous_word_start_pos := scan_to_previous_word_start(gb, cursor.Pos.new(15, 0), 0)? // cursor starting on 's' in word 'first'
	assert previous_word_start_pos == cursor.Pos.new(12, 0)
	assert get_char_at(gb, previous_word_start_pos) == 'f'

	previous_word_start_pos = scan_to_previous_word_start(gb, previous_word_start_pos, 0)? // cursor should now be on 't' of word 'the'
	assert previous_word_start_pos == cursor.Pos.new(11, 0)
	assert get_char_at(gb, previous_word_start_pos) == '.'

	previous_word_start_pos = scan_to_previous_word_start(gb, previous_word_start_pos, 0)? // cursor should now be on 't' of word 'the'
	assert previous_word_start_pos == cursor.Pos.new(8, 0)
	assert get_char_at(gb, previous_word_start_pos) == 't'

	previous_word_start_pos = scan_to_previous_word_start(gb, previous_word_start_pos, 0)? // cursor should now be on 't' of word 'the'
	assert previous_word_start_pos == cursor.Pos.new(5, 0)
	assert get_char_at(gb, previous_word_start_pos) == 'i'
}

fn get_char_at(data buffers.GapBuffer, pos cursor.Pos) string {
	return [data.get_char_at(y: pos.y, x: pos.x) or { '?'.runes()[0] }].string()
}

fn test_doc_move_cursor_to_next_word_start() {
	mut d := Document{
		file_path: ''
		data: buffers.GapBuffer.new(content: mock_content.runes())
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

fn test_doc_move_cursor_to_previous_word_start() {
	mut d := Document{
		file_path: ''
		data: buffers.GapBuffer.new(content: mock_content.runes())
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

const mock_punct_content := 'abc() {'

fn test_doc_move_cursor_to_previous_word_start_with_punct() {
	mut d := Document{
		file_path: ''
		data: buffers.GapBuffer.new(content: mock_punct_content.runes())
	}

	// backward from { should land on start of ()
	assert d.move_cursor_to_previous_word_start(cursor.Pos.new(6, 0)) == cursor.Pos.new(3, 0)
	// backward from () should land on start of abc
	assert d.move_cursor_to_previous_word_start(cursor.Pos.new(3, 0)) == cursor.Pos.new(0, 0)
}

fn test_doc_move_cursor_to_next_word_start_with_punct() {
	mut d := Document{
		file_path: ''
		data: buffers.GapBuffer.new(content: mock_punct_content.runes())
	}

	// forward from abc should land on (
	assert d.move_cursor_to_next_word_start(cursor.Pos.new(0, 0)) == cursor.Pos.new(3, 0)
	// forward from () should land on {
	assert d.move_cursor_to_next_word_start(cursor.Pos.new(3, 0)) == cursor.Pos.new(6, 0)
}

const mock_crossline_punct_content := 'struct EditorModel {
	id int'

fn test_doc_move_cursor_to_previous_word_start_cross_line_lands_on_brace() {
	mut d := Document{
		file_path: ''
		data: buffers.GapBuffer.new(content: mock_crossline_punct_content.runes())
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
		data: buffers.GapBuffer.new(content: mock_content.runes())
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
		data: buffers.GapBuffer.new(content: mock_punct_content.runes())
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
		data: buffers.GapBuffer.new(content: mock_content.runes())
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
		data: buffers.GapBuffer.new(content: mock_content.runes())
	}

	// 'This is the.first line\nThis is the second line.'
	// ge from 'T' of 'This' on line 1 → 'e' (end of 'line' on line 0)
	assert d.move_cursor_to_previous_word_end(cursor.Pos.new(0, 1)) == cursor.Pos.new(21, 0)
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
		data: buffers.GapBuffer.new(content: mock_multiline_content_with_blanks.runes())
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
		data: buffers.GapBuffer.new(content: mock_multiline_content_with_blanks.runes())
	}

	assert d.move_cursor_to_previous_blank_line(cursor.Pos.new(8, 9)) == cursor.Pos.new(0, 8)
	assert d.move_cursor_to_previous_blank_line(cursor.Pos.new(0, 8)) == cursor.Pos.new(0, 5)
	assert d.move_cursor_to_previous_blank_line(cursor.Pos.new(0, 5)) == cursor.Pos.new(0, 2)
	assert d.move_cursor_to_previous_blank_line(cursor.Pos.new(0, 2)) == cursor.Pos.new(0, 0)
	assert d.move_cursor_to_previous_blank_line(cursor.Pos.new(0, 0)) == cursor.Pos.new(0, 0)
}

