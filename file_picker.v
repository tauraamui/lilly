module main

import tauraamui.bobatea as tea

struct FilePickerModel {
mut:
	width int
	height int
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
	return tea.emit_resize
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
		tea.ResizedMsg {
			m.width = msg.window_width / 2
			m.height = msg.window_height / 2
		}
		else {}
	}
	return m.clone(), none
}

const bordered_layout = tea.new_layout()
	.border(.normal)
	.border_color(tea.Color.ansi(69))

fn (m FilePickerModel) view(mut ctx tea.Context) {
	id := ctx.push_offset(tea.Offset{ x: (ctx.window_width() / 2) - m.width / 2, y: (ctx.window_height() / 2) - m.height / 2 })
	defer { ctx.clear_offsets_from(id) }

	bordered_layout.size(m.width, m.height).render(mut ctx, fn [m] (mut ctx tea.Context) {
		ctx.set_clip_area(tea.ClipArea{ 0, 0, m.width - 3, m.height - 3 }) // being within a bordered layout requires narrower clip area
		defer { ctx.clear_clip_area() }
		// > manually clear all content below model to effectfully make it opaque
		ctx.draw_rect(0, 0, m.width, m.height)
		// >
		model_content := "FILE PICKER"
		ctx.draw_text(0, 0, model_content)
	})
}

fn (m FilePickerModel) clone() tea.Model {
	return FilePickerModel{
		...m
	}
}

