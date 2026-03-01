module documents

import lib.buffers

const mock_content := 'This is the first line
This is the second line.'

/*
fn test_scan_to_next_word_start() {
	gb := buffers.GapBuffer.new(content: mock_content.runes())
	assert scan_to_next_word_start(gb, CursorPos{ y: 0, x: 0 }, false) == CursorPos{ y: 0, x: 8 }
}
*/

fn test_char_scanner() {
	mut c_scanner := CharScanner{
		data: 'This is some test content'.runes()
	}

	assert c_scanner.next_diff(.alpha_num)? == ScanResult{ index: 4, cchar: ' '.runes()[0], c_type: .whitespace }
	assert c_scanner.next_diff(.whitespace)? == ScanResult{ index: 5, cchar: 'i'.runes()[0], c_type: .alpha_num }
}

