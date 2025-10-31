module main

import tauraamui.bobatea as tea

struct FilePickerModel {
}

struct OpenDialogMsg {
	model tea.Model
}

struct CloseDialogMsg {}

fn open_file_picker() tea.Msg {
	return OpenDialogMsg{
		model: FilePickerModel{}
	}
}

fn close_file_picker() tea.Msg {
	return CloseDialogMsg{}
}

fn (mut m FilePickerModel) init() ?tea.Cmd {
	return none
}

fn (mut m FilePickerModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	match msg {
		tea.KeyMsg {
			match msg.string() {
				"escape" { return FilePickerModel{}, close_file_picker }
				"ctrl+c" { return FilePickerModel{}, tea.quit }
				else {}
			}
		}
		else {}
	}
	return m.clone(), none
}

fn (m FilePickerModel) view(mut ctx tea.Context) {
	model_content := "FILE PICKER"
	ctx.set_bg_color(tea.Color.ansi(55))
	ctx.draw_text((ctx.window_width() / 2) - tea.visible_len(model_content) / 2, ctx.window_height() / 2, model_content)
	ctx.reset_bg_color()
}

fn (m FilePickerModel) clone() tea.Model {
	return FilePickerModel{
		...m
	}
}

