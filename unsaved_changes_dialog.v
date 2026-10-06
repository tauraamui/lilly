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
import lib.petal.theme
import lib.nanoid

// UnsavedChangesDialogModel asks what to do about a document with unwritten
// edits whose last editor is about to go away.
//
// then_open names the file that was being opened over the editor, when that is
// what triggered the question rather than a quit. It is carried through the
// dialog so that answering it resumes the interrupted action instead of
// leaving the user to repeat it.
struct UnsavedChangesDialogModel {
	theme     theme.Theme
	editor_id nanoid.ID
	file_path string
	then_open ?string
mut:
	width  int = 68
	height int = 9
}

fn open_unsaved_changes_dialog(ttheme theme.Theme, editor_id nanoid.ID, file_path string, then_open ?string) tea.Cmd {
	return tea.msg_cmd(OpenDialogMsg{
		model: UnsavedChangesDialogModel{
			theme:     ttheme
			editor_id: editor_id
			file_path: file_path
			then_open: then_open
		}
	})
}

fn close_unsaved_changes_dialog() tea.Cmd {
	return tea.msg_cmd(CloseDialogMsg{})
}

fn (mut m UnsavedChangesDialogModel) init() tea.Cmd {
	return tea.no_cmd
}

fn (mut m UnsavedChangesDialogModel) update(msg tea.Msg) (tea.Model, tea.Cmd) {
	match msg {
		tea.KeyMsg {
			match msg.k_type {
				.special {
					match msg.string() {
						'escape', 'ctrl+c' {
							return m.clone(), close_unsaved_changes_dialog()
						}
						else {}
					}
				}
				.runes {
					match msg.string() {
						's' {
							return m.clone(), tea.sequence(close_unsaved_changes_dialog(),
								resolve_unsaved_changes(m.editor_id, true, m.then_open))
						}
						'd' {
							return m.clone(), tea.sequence(close_unsaved_changes_dialog(),
								resolve_unsaved_changes(m.editor_id, false, m.then_open))
						}
						'c' {
							return m.clone(), close_unsaved_changes_dialog()
						}
						else {}
					}
				}
			}
		}
		else {}
	}
	return m.clone(), tea.no_cmd
}

fn (m UnsavedChangesDialogModel) view(mut r_ctx tea.Context) {
	r_ctx.clear_area(0, 0, m.width, m.height)

	// drawn inline rather than in a render callback: the callback would capture
	// this model, and V pins a closure's captured context for the life of the
	// process
	layout := tea.new_layout().border(.normal).border_color(m.theme.petal_red).size(m.width,
		m.height)
	layout.render_begin(mut r_ctx)
	defer { layout.render_end(mut r_ctx) }
	m.draw_dialog_body(mut r_ctx)
}

fn (m UnsavedChangesDialogModel) draw_dialog_body(mut ctx tea.Context) {
	ctx.draw_text(2, 1, 'Unsaved changes')

	name := os.file_name(m.file_path)
	ctx.set_color(m.theme.subtle_light_grey)
	ctx.draw_text(2, 3, truncate_to_width('${name} has edits that have not been written,',
		m.width - 4))
	ctx.draw_text(2, 4, 'and no other split is showing it.')
	ctx.reset_color()

	// the question is the same either way, but the consequence is not: this
	// dialog also stands in front of an open that is about to replace the
	// editor, and offering to "close" there would describe the wrong outcome
	verb := if m.then_open != none { 'open' } else { 'close' }
	ctx.set_color(m.theme.petal_pink)
	ctx.draw_text(2, m.height - 4, 's: save and ${verb}  •  d: discard and ${verb}  •  c/Esc: cancel')
	ctx.reset_color()
}

// truncate_to_width keeps a line inside the dialog's border. A long path would
// otherwise be drawn straight through the right-hand edge.
fn truncate_to_width(text string, width int) string {
	if width <= 0 {
		return ''
	}
	if tea.visible_len(text) <= width {
		return text
	}
	if width <= 1 {
		return '…'
	}
	runes := text.runes()
	return runes[..width - 1].string() + '…'
}

fn (m UnsavedChangesDialogModel) width() int {
	return m.width
}

fn (m UnsavedChangesDialogModel) height() int {
	return m.height
}

fn (m UnsavedChangesDialogModel) debug_data() DebugData {
	return DebugData{
		name: 'unsaved changes dialog'
		data: {
			'file':      m.file_path
			'editor id': '${m.editor_id}'
			'then open': m.then_open or { '' }
		}
	}
}

fn (m UnsavedChangesDialogModel) clone() tea.Model {
	return UnsavedChangesDialogModel{
		...m
	}
}
