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

module main

import os
import bobatea as tea
import lib.documents
import lib.nanoid
import lib.palette

struct EditorModel {
	doc_id nanoid.ID
	doc_controller &documents.Controller2
}

fn EditorModel.new(doc_id nanoid.ID, doc_controller &documents.Controller2) EditorModel {
	return EditorModel{
		doc_id: doc_id
		doc_controller: doc_controller
	}
}

fn (mut m EditorModel) init() fn () tea.Msg {
	return tea.noop_cmd
}

fn (mut m EditorModel) update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
	return m.normal_mode_update(msg)
}

fn (mut m EditorModel) normal_mode_update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
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
						'ctrl+i' { // TAB
							m.doc_controller.insert(m.doc_id, `\t`)
						}
						'backspace' {
							m.doc_controller.backspace(m.doc_id)
						}
						'delete' {
							m.doc_controller.delete(m.doc_id)
						}
						'left' {
							m.doc_controller.move_cursor_left(m.doc_id)
						}
						'down' {
							m.doc_controller.move_cursor_down(m.doc_id)
						}
						'right' {
							m.doc_controller.move_cursor_right(m.doc_id)
						}
						'up' {
							m.doc_controller.move_cursor_up(m.doc_id)
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
	for y in 0..line_count {
		line_bytes := m.doc_controller.get_line_bytes(m.doc_id, u64(y)) or { []u8{} }
		ctx.draw_text(0, y, line_bytes.bytestr().replace('\t', '    '))
	}
}

fn (m EditorModel) clone() tea.Model {
	return EditorModel{
		...m
	}
}

fn main() {
	file_path := '/home/tauraamui/src/lilly/editor.v'
	mut documents_controller := documents.Controller2.new()

	doc_id := documents_controller.open_document(file_path) or {
		eprintln('failed to open document: ${err}')
		exit(1)
	}

	mut editor_model := EditorModel.new(doc_id, &documents_controller)
	mut app := tea.new_program(mut editor_model)
	app.run() or { panic('something went wrong!: ${err}') }
}

