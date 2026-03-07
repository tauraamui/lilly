module documents

import lib.buffers

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

const mock_content := 'This is the first line
This is the second line.'

fn test_scan_to_next_word_start() {
	gb := buffers.GapBuffer.new(content: mock_content.runes())

	mut next_word_start_pos := scan_to_next_word_start(gb, CursorPos{ y: 0, x: 0 }, 0)?
	assert next_word_start_pos == CursorPos{ y: 0, x: 5 }
	assert get_char_at(gb, next_word_start_pos) == 'i'

	next_word_start_pos = scan_to_next_word_start(gb, next_word_start_pos, 0)?
	assert next_word_start_pos == CursorPos{ y: 0, x: 8 }
	assert get_char_at(gb, next_word_start_pos) == 't'

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
	assert previous_word_start_pos == CursorPos{ y: 0, x: 8 }
	assert get_char_at(gb, previous_word_start_pos) == 't'
}

fn get_char_at(data buffers.GapBuffer, pos CursorPos) string {
	return [data.get_char_at(y: pos.y, x: pos.x) or { '?'.runes()[0] }].string()
}

