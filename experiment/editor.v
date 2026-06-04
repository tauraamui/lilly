module main

import os
import bobatea as tea
import lib.documents
import lib.palette

struct EditorModel {
	doc_id int
	doc_controller &documents.Controller2
}

fn EditorModel.new(doc_id int, doc_controller &documents.Controller2) EditorModel {
	return EditorModel{
		doc_id: doc_id
		doc_controller: doc_controller
	}
}

fn (mut m EditorModel) init() fn () tea.Msg {
	return tea.noop_cmd
}

fn (mut m EditorModel) update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
	match msg {
		tea.KeyMsg {
			match msg.k_type {
				.runes {
					for cb in msg.string().bytes() {
						m.doc_controller.insert(m.doc_id, cb)
					}
				}
				.special {
					match msg.string() {
						'escape' {
							return m.clone(), tea.quit
						}
						'enter' {
							m.doc_controller.insert(m.doc_id, `\n`)
						}
						'left' {
							m.doc_controller.move_cursor_left(m.doc_id)
						}
						'right' {
							m.doc_controller.move_cursor_right(m.doc_id)
						}
						else {}
					}
				}
			}
		}
		else {}
	}
	return m.clone(), tea.noop_cmd
}

fn (mut m EditorModel) view(mut ctx tea.Context) {
	cursor_line, cursor_x := m.doc_controller.cursor_line_and_x(m.doc_id)
	line_count := int(m.doc_controller.line_count(m.doc_id))
	mut cursor_char_bytes := []u8{}
	mut cursor_char_set := false
	for y in 0..line_count {
		line_bytes := m.doc_controller.get_line_bytes(m.doc_id, u64(y)) or { []u8{} }
		ctx.draw_text(0, y, line_bytes.bytestr())
		if cursor_line == u64(y) {
			cursor_char_set = true
			start := int(cursor_x)
			if start < line_bytes.len {
				char_len := utf8_codepoint_len(line_bytes[start])
				mut end := start + char_len
				if end > line_bytes.len {
					end = start + 1
				}
				cursor_char_bytes = line_bytes[start..end]
			} else {
				cursor_char_bytes = [u8(` `)]
			}
		}
	}
	cursor_char_str := if cursor_char_set && cursor_char_bytes.len > 0 && cursor_char_bytes[0] != `\n` {
		cursor_char_bytes.bytestr()
	} else {
		' '
	}
	cursor_x_i := int(cursor_x)
	cursor_y_i := int(cursor_line)
	default_bg := ctx.get_default_bg_color() or { palette.matte_black_bg_color }
	ctx.set_bg_color(palette.fg_color(default_bg))
	ctx.set_color(default_bg)
	ctx.draw_text(cursor_x_i, cursor_y_i, cursor_char_str)
	ctx.reset_bg_color()
	ctx.reset_color()
}

fn utf8_codepoint_len(start_byte u8) int {
	if start_byte & 0b10000000 == 0 {
		return 1
	}
	if start_byte & 0b11100000 == 0b11000000 {
		return 2
	}
	if start_byte & 0b11110000 == 0b11100000 {
		return 3
	}
	if start_byte & 0b11111000 == 0b11110000 {
		return 4
	}
	return 1
}

fn (m EditorModel) clone() tea.Model {
	return EditorModel{
		...m
	}
}

fn main() {
	file_path := os.join_path(os.temp_dir(), 'test_LF.txt')
	defer { os.rm(file_path) or { println('failed to delete ${file_path}: ${err}') } }
	os.write_file(file_path, 'hello\nWoRlD<\n😍')!

	mut documents_controller := documents.Controller2.new()

	doc_id := documents_controller.open_document(file_path) or {
		eprintln('failed to open document: ${err}')
		exit(1)
	}

	mut editor_model := EditorModel.new(doc_id, &documents_controller)
	mut app := tea.new_program(mut editor_model)
	app.run() or { panic('something went wrong!: ${err}') }
}

