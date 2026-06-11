module documents

import os

/*
fn test_controller_backspace_on_given_document() {
	mock_doc_id := 1
	mut c := Controller2{
		docs: { mock_doc_id: buffers.TextBuffer.new() or { panic(err) } }
	}
	c.insert(mock_doc_id, u8(`a`))
}
*/

fn test_controller_open_document_from_path() {
	file_path := os.join_path(os.temp_dir(), 'test_LF.txt')
	defer { os.rm(file_path) or { println('failed to delete ${file_path}: ${err}') } }
	os.write_file(file_path, 'hello\nWoRlD<')!

	mut c := Controller2{}
	assert c.open_document(file_path)! == 0
	assert c.get_line_bytes(0, 0)? == [u8(`h`), `e`, `l`, `l`, `o`]
	assert c.get_line_bytes(0, 1)? == [u8(`W`), `o`, `R`, `l`, `D`, `<`]
}

fn test_controller_open_document_from_path_subsequent_edits() {
	file_path := os.join_path(os.temp_dir(), 'test_LF.txt')
	defer { os.rm(file_path) or { println('failed to delete ${file_path}: ${err}') } }
	os.write_file(file_path, 'hello\nWoRlD<')!

	mut c := Controller2{}
	assert c.open_document(file_path)! == 0
	assert c.get_line_bytes(0, 0)? == [u8(`h`), `e`, `l`, `l`, `o`]
	assert c.get_line_bytes(0, 1)? == [u8(`W`), `o`, `R`, `l`, `D`, `<`]
	
	c.backspace(0)
	assert c.get_line_bytes(0, 0)? == [u8(`h`), `e`, `l`, `l`, `o`]
	assert c.get_line_bytes(0, 1)? == [u8(`W`), `o`, `R`, `l`, `D`, `<`]

	c.move_cursor_right(0)
	c.move_cursor_right(0)
	c.backspace(0)
	assert c.get_line_bytes(0, 0)? == [u8(`h`), `l`, `l`, `o`]
	assert c.get_line_bytes(0, 1)? == [u8(`W`), `o`, `R`, `l`, `D`, `<`]
}

fn test_controller_insert_after_load_goes_to_start() {
	file_path := os.join_path(os.temp_dir(), 'test_LF_insert_start.txt')
	defer { os.rm(file_path) or { println('failed to delete ${file_path}: ${err}') } }
	os.write_file(file_path, 'hello\nWoRlD<')!

	mut c := Controller2{}
	doc_id := c.open_document(file_path)!
	c.insert(doc_id, u8(`>`))

	assert c.get_line_bytes(doc_id, 0)? == [u8(`>`), `h`, `e`, `l`, `l`, `o`]
	assert c.get_line_bytes(doc_id, 1)? == [u8(`W`), `o`, `R`, `l`, `D`, `<`]
}

