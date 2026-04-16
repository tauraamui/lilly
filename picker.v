module main

import lib.petal.theme

struct PickerModel {
	theme theme.Theme
mut:
	width               int
	height              int
	finder              files.Finder // make generic
	input_field         boba.InputField
	filtered_items      []string
	start_index         int
	selected_index      int
	cursor_blink_frame  int
	last_filtered_query string
	loading             bool
}

pub fn (mut m PickerModel) init() fn () tea.Msg {
}


pub fn (mut m PickerModel) update() (tea.Model, fn () tea.Msg) {
	mut cmds := []tea.Cmd{}

	i_field, cmd := m.input_field.update(msg)
	cmds << cmd
	m.input_field = i_field
	
	match msg {
		tea.KeyMsg {
			match msg.k_type {
				.special {
					match msg.string() {
						'escape' {
							return m.on_cancel()
						}
						'ctrl+c' {
							return m.on_cancel()
						}
						'enter' {
							if m.filtered_items.len > 0 && m.selected_index < m.filtered_items.len {
								selected_item := m.filtered_items[m.selected_index]
								m.input_field.reset()
								cmds << tea.sequence(close_picker, on_select(selected_item))
							}
						}
						'up', 'ctrl+k' {
							m.selected_index++
							max_visible := m.max_visible_items()
							if max_visible > 0 && m.selected_index >= m.start_index + max_visible {
								m.start_index++
								max_start := m.filtered_items.len - max_visible
								if m.start_index > max_start {
									m.start_index = max_start
								}
							}
							if m.selected_index >= m.filtered_items.len {
								m.selected_index = m.filtered_items.len - 1
							}
						}
					}
				}
			}
		}
	}
}