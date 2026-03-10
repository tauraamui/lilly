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

	assert d.move_cursor_left(CursorPos{ x: 8, y: 0 }, .normal) == CursorPos{ x: 7, y: 0 }
}

fn test_document_move_cursor_left_new() {
	d := Document{
		file_path: ''
		data: buffers.GapBuffer.new(content: mock_content.runes())
	}

	assert d.move_cursor_left_new(cursor.Pos.new(8, 0)) == cursor.Pos.new(7, 0)
}

fn test_scan_to_next_word_start() {
	gb := buffers.GapBuffer.new(content: mock_content.runes())

	mut next_word_start_pos := scan_to_next_word_start(gb, CursorPos{ y: 0, x: 0 }, 0)?
	assert next_word_start_pos == CursorPos{ y: 0, x: 5 }
	assert get_char_at(gb, next_word_start_pos) == 'i'

	next_word_start_pos = scan_to_next_word_start(gb, next_word_start_pos, 0)?
	assert next_word_start_pos == CursorPos{ y: 0, x: 8 }
	assert get_char_at(gb, next_word_start_pos) == 't'

	next_word_start_pos = scan_to_next_word_start(gb, next_word_start_pos, 0)?
	assert next_word_start_pos == CursorPos{ y: 0, x: 11 }
	assert get_char_at(gb, next_word_start_pos) == '.'

	next_word_start_pos = scan_to_next_word_start(gb, next_word_start_pos, 0)?
	assert next_word_start_pos == CursorPos{ y: 0, x: 12 }
	assert get_char_at(gb, next_word_start_pos) == 'f'
}

fn test_scan_to_previous_word_start() {
	gb := buffers.GapBuffer.new(content: mock_content.runes())
	mut previous_word_start_pos := scan_to_previous_word_start(gb, CursorPos{ y: 0, x: 15 }, 0)? // cursor starting on 's' in word 'first'
	assert previous_word_start_pos == CursorPos{ y: 0, x: 12 }
	assert get_char_at(gb, previous_word_start_pos) == 'f'

	previous_word_start_pos = scan_to_previous_word_start(gb, previous_word_start_pos, 0)? // cursor should now be on 't' of word 'the'
	assert previous_word_start_pos == CursorPos{ y: 0, x: 11 }
	assert get_char_at(gb, previous_word_start_pos) == '.'

	previous_word_start_pos = scan_to_previous_word_start(gb, previous_word_start_pos, 0)? // cursor should now be on 't' of word 'the'
	assert previous_word_start_pos == CursorPos{ y: 0, x: 8 }
	assert get_char_at(gb, previous_word_start_pos) == 't'

	previous_word_start_pos = scan_to_previous_word_start(gb, previous_word_start_pos, 0)? // cursor should now be on 't' of word 'the'
	assert previous_word_start_pos == CursorPos{ y: 0, x: 5 }
	assert get_char_at(gb, previous_word_start_pos) == 'i'
}

fn get_char_at(data buffers.GapBuffer, pos CursorPos) string {
	return [data.get_char_at(y: pos.y, x: pos.x) or { '?'.runes()[0] }].string()
}

fn test_doc_move_cursor_to_next_word_start() {
	mut d := Document{
		file_path: ''
		data: buffers.GapBuffer.new(content: mock_content.runes())
	}

	assert d.move_cursor_to_previous_word_start(CursorPos{ y: 0, x: 15 }) == CursorPos{ y: 0, x: 12 }
	assert d.move_cursor_to_previous_word_start(CursorPos{ y: 0, x: 12 }) == CursorPos{ y: 0, x: 11 }
	assert d.move_cursor_to_previous_word_start(CursorPos{ y: 0, x: 11 }) == CursorPos{ y: 0, x: 8 }
	assert d.move_cursor_to_previous_word_start(CursorPos{ y: 0, x: 8 }) == CursorPos{ y: 0, x: 5 }
	assert d.move_cursor_to_previous_word_start(CursorPos{ y: 0, x: 5 }) == CursorPos{ y: 0, x: 0 }
	assert d.move_cursor_to_previous_word_start(CursorPos{ y: 0, x: 0 }) == CursorPos{ y: 0, x: 0 }

	assert d.move_cursor_to_previous_word_start(CursorPos{ y: 1, x: 16 }) == CursorPos{ y: 1, x: 12 }
	assert d.move_cursor_to_previous_word_start(CursorPos{ y: 1, x: 12 }) == CursorPos{ y: 1, x: 8 }
	assert d.move_cursor_to_previous_word_start(CursorPos{ y: 1, x: 8 }) == CursorPos{ y: 1, x: 5 }
	assert d.move_cursor_to_previous_word_start(CursorPos{ y: 1, x: 5 }) == CursorPos{ y: 1, x: 0 }
	assert d.move_cursor_to_previous_word_start(CursorPos{ y: 1, x: 0 }) == CursorPos{ y: 0, x: 18 }
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

	assert d.move_cursor_to_next_blank_line(CursorPos{ y: 0, x: 8 }) == CursorPos{ y: 2, x: 0 }
	assert d.move_cursor_to_next_blank_line(CursorPos{ y: 2, x: 0 }) == CursorPos{ y: 5, x: 0 }
	assert d.move_cursor_to_next_blank_line(CursorPos{ y: 5, x: 0 }) == CursorPos{ y: 8, x: 0 }
	assert d.move_cursor_to_next_blank_line(CursorPos{ y: 8, x: 0 }) == CursorPos{ y: 9, x: 0 }
	assert d.move_cursor_to_next_blank_line(CursorPos{ y: 9, x: 0 }) == CursorPos{ y: 9, x: 0 }

}

fn test_doc_move_cursor_to_previous_blank_line() {
	mut d := Document{
		file_path: ''
		data: buffers.GapBuffer.new(content: mock_multiline_content_with_blanks.runes())
	}

	assert d.move_cursor_to_previous_blank_line(CursorPos{ y: 9, x: 8 }) == CursorPos{ y: 8, x: 0 }
	assert d.move_cursor_to_previous_blank_line(CursorPos{ y: 8, x: 0 }) == CursorPos{ y: 5, x: 0 }
	assert d.move_cursor_to_previous_blank_line(CursorPos{ y: 5, x: 0 }) == CursorPos{ y: 2, x: 0 }
	assert d.move_cursor_to_previous_blank_line(CursorPos{ y: 2, x: 0 }) == CursorPos{ y: 0, x: 0 }
	assert d.move_cursor_to_previous_blank_line(CursorPos{ y: 0, x: 0 }) == CursorPos{ y: 0, x: 0 }
}

