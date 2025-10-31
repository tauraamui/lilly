module main

import tauraamui.bobatea as tea

struct FilePickerModel {
	width int
	height int
}

struct OpenDialogMsg {
	model tea.Model
}

struct CloseDialogMsg {}

fn open_file_picker() tea.Msg {
	return OpenDialogMsg{
		model: FilePickerModel{
			width: 80
			height: 30
		}
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
				"ctrl+c" { return FilePickerModel{}, close_file_picker }
				else {}
			}
		}
		else {}
	}
	return m.clone(), none
}

const bordered_layout = tea.new_layout()
	.border(.normal)
	.border_color(tea.Color.ansi(69))
	.padding_all(1)

fn (m FilePickerModel) view(mut ctx tea.Context) {
	id := ctx.push_offset(tea.Offset{ x: (ctx.window_width() / 2) - m.width / 2, y: (ctx.window_height() / 2) - m.height / 2 })
	defer { ctx.clear_offsets_from(id) }
	bordered_layout.size(m.width, m.height).render(mut ctx, fn [m] (mut ctx tea.Context) {
		model_content := "FILE PICKER"
		ctx.set_bg_color(tea.Color.ansi(55))
		ctx.draw_text(0, 0, model_content)
		ctx.reset_bg_color()
	})
}

fn (m FilePickerModel) clone() tea.Model {
	return FilePickerModel{
		...m
	}
}

