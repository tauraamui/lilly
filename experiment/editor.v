module main

import os
import bobatea as tea
import lib.documents
import lib.buffers

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
	for y in 0..m.doc_controller.line_count(m.doc_id) {
		line_bytes := m.doc_controller.get_line_bytes(m.doc_id, u64(y)) or { continue }
		ctx.draw_text(0, int(y), line_bytes.bytestr())
	}
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

