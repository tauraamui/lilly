module documents

import os
import lib.buffers

fn test_controller_backspace_on_given_document() {
	mock_doc_id := 1
	mut c := Controller2{
		docs: { mock_doc_id: buffers.TextBuffer.new() }
	}
	c.insert(mock_doc_id, u8(`a`))
}

fn test_controller_open_document_from_path() {
	file_path := os.join_path(os.temp_dir(), 'test_LF.txt')
	defer { os.rm(file_path) or { println('failed to delete ${file_path}: ${err}') } }
	os.write_file(file_path, 'hello\nWoRlD<')!

	mut c := Controller2{}
	assert c.open_document(file_path)! == 0
	assert c.get_line_bytes(0, 0)? == [u8(`h`), `e`, `l`, `l`, `o`, `\n`]
	assert c.get_line_bytes(0, 1)? == [u8(`W`), `o`, `R`, `l`, `D`, `<`]
}

fn test_controller_open_document_from_path_subsequent_edits() {
	file_path := os.join_path(os.temp_dir(), 'test_LF.txt')
	defer { os.rm(file_path) or { println('failed to delete ${file_path}: ${err}') } }
	os.write_file(file_path, 'hello\nWoRlD<')!

	mut c := Controller2{}
	assert c.open_document(file_path)! == 0
	assert c.get_line_bytes(0, 0)? == [u8(`h`), `e`, `l`, `l`, `o`, `\n`]
	assert c.get_line_bytes(0, 1)? == [u8(`W`), `o`, `R`, `l`, `D`, `<`]
	
	c.backspace(0)
	assert c.get_line_bytes(0, 0)? == [u8(`h`), `e`, `l`, `l`, `o`, `\n`]
	assert c.get_line_bytes(0, 1)? == [u8(`W`), `o`, `R`, `l`, `D`, `<`]
}

