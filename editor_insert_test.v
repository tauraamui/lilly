module main

import os
import time
import lib.documents
import lib.cfg
import bobatea as tea

fn make_insert_test_file(label string, content string) string {
	path := os.join_path(os.temp_dir(), 'lilly_insert_${label}_${time.now().unix_nano()}')
	os.write_file(path, content) or { panic('failed to write temp file: ${err}') }
	return path
}

fn test_insert_enter_injects_prev_line_prefix() {
	file_path := make_insert_test_file('prefix', 'This is a line.\n\tA padded line.')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	mut m := EditorModel{
		config:         EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:         doc_id
		doc_controller: &c
	}

	c.move_cursor_down(doc_id)
	c.jump_cursor_to_line_end(doc_id)

	pre_newline_line_y, _ := c.cursor_line_and_x(doc_id)
	assert pre_newline_line_y == 1

	m.insert_mode_update(tea.KeyMsg{
		k_type: .special
		runes:  'enter'.runes()
	})
	m.insert_mode_update(tea.KeyMsg{
		k_type: .runes
		runes:  'A third but indented line.'.runes()
	})

	post_newline_line_y, _ := c.cursor_line_and_x(doc_id)
	assert post_newline_line_y == 2
	assert c.line_count(doc_id) == 3
	assert c.get_line_bytes(doc_id, 0)? == 'This is a line.'.bytes()
	assert c.get_line_bytes(doc_id, 1)? == '\tA padded line.'.bytes()
	assert c.get_line_bytes(doc_id, 2)? == '\tA third but indented line.'.bytes()

	c.jump_cursor_to_line_start(doc_id)
	m.insert_mode_update(tea.KeyMsg{
		k_type: .runes
		runes:  '\t'.runes()
	})
	c.jump_cursor_to_line_end(doc_id)
	m.insert_mode_update(tea.KeyMsg{
		k_type: .special
		runes:  'enter'.runes()
	})

	assert c.line_count(doc_id) == 4
	assert c.get_line_bytes(doc_id, 3)? == '\t\t'.bytes()
}
