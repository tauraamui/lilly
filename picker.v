module main

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
}