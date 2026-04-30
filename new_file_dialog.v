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
import lib.boba

struct NewFileDialogModel {
	theme theme.Theme
mut:
	width       int = 70
	height      int = 11
	input_field boba.InputField
	error_msg   string
}

struct CreateAndOpenFileMsg {
	path string
}

fn create_and_open_file(path string) tea.Cmd {
	return fn [path] () tea.Msg {
		return CreateAndOpenFileMsg{path}
	}
}

fn open_new_file_dialog(ttheme theme.Theme) tea.Cmd {
	return fn [ttheme] () tea.Msg {
		return OpenDialogMsg{
			model: NewFileDialogModel{
				theme: ttheme
			}
		}
	}
}

fn close_new_file_dialog() tea.Msg {
	return CloseDialogMsg{}
}

fn (mut m NewFileDialogModel) init() fn () tea.Msg {
	m.input_field = boba.BorderedInputField.new(m.theme.petal_pink)
	m.input_field.focus()
	mut cmds := []tea.Cmd{}
	cmds << m.input_field.init()
	resized_field, resized_cmd := m.input_field.update(tea.ResizedMsg{
		window_width:  m.input_width()
		window_height: 1
	})
	cmds << resized_cmd
	m.input_field = resized_field
	return tea.batch_array(cmds)
}

fn (mut m NewFileDialogModel) update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
	mut cmds := []tea.Cmd{}
	field, field_cmd := m.input_field.update(msg)
	cmds << field_cmd
	m.input_field = field

	if msg is tea.ResizedMsg {
		resized_field, resized_cmd := m.input_field.update(tea.ResizedMsg{
			window_width:  m.input_width()
			window_height: 1
		})
		cmds << resized_cmd
		m.input_field = resized_field
	}

	match msg {
		tea.KeyMsg {
			match msg.k_type {
				.special {
					match msg.string() {
						'escape' {
							return m.clone(), close_new_file_dialog
						}
						'ctrl+c' {
							return m.clone(), close_new_file_dialog
						}
						'enter' {
							abs_path := validate_new_file_path(m.input_field.value()) or {
								m.error_msg = err.msg()
								return m.clone(), tea.batch_array(cmds)
							}
							m.error_msg = ''
							cmds << tea.sequence(close_new_file_dialog,
								create_and_open_file(abs_path))
							return m.clone(), tea.batch_array(cmds)
						}
						else {}
					}
				}
				else {}
			}
		}
		else {}
	}

	return m.clone(), tea.batch_array(cmds)
}

fn (m NewFileDialogModel) view(mut r_ctx tea.Context) {
	r_ctx.clear_area(0, 0, m.width, m.height)
	mut inner_height := m.height - 2
	if inner_height < 0 {
		inner_height = 0
	}

	tea.new_layout().border(.normal).border_color(m.theme.petal_pink).size(m.width, m.height).render(mut r_ctx, fn [m, inner_height] (mut ctx tea.Context) {
		title := 'Create new file'
		ctx.draw_text(2, 1, title)

		path_label_y := 3
		ctx.draw_text(2, path_label_y, 'Path')
		input_offset := ctx.push_offset(tea.Offset{
			x: 2
			y: path_label_y + 1
		})
		m.input_field.view(mut ctx)
		ctx.clear_offsets_from(input_offset)

		if m.error_msg.len > 0 {
			ctx.set_color(m.theme.petal_red)
			ctx.draw_text(2, inner_height - 4, m.error_msg)
			ctx.reset_color()
		}

		ctx.set_color(m.theme.subtle_light_grey)
		ctx.draw_text(2, inner_height - 2, 'Enter to create • Esc to cancel')
		ctx.reset_color()
	})
}

fn (m NewFileDialogModel) width() int {
	return m.width
}

fn (m NewFileDialogModel) height() int {
	return m.height
}

fn (m NewFileDialogModel) debug_data() DebugData {
	return DebugData{
		name: 'new file dialog'
		data: {
			'error': m.error_msg
		}
	}
}

fn (m NewFileDialogModel) clone() tea.Model {
	return NewFileDialogModel{
		...m
	}
}

fn (m NewFileDialogModel) input_width() int {
	inner_width := m.width - 4
	return if inner_width > 0 { inner_width } else { m.width }
}

fn validate_new_file_path(raw_path string) !string {
	trimmed := raw_path.trim_space()
	if trimmed.len == 0 {
		return error('path is required')
	}

	abs_path := os.abs_path(trimmed)

	if os.is_dir(abs_path) {
		return error('path points to a directory')
	}

	if os.exists(abs_path) {
		return error('file already exists')
	}

	parent := os.dir(abs_path)
	if parent.len > 0 && !os.exists(parent) {
		return error('parent directory does not exist')
	}

	return abs_path
}
