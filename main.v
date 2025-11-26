module main

import tauraamui.bobatea as tea
import palette

fn main() {
	mut petal_model := PetalModel.new(palette.theme_bg_color)
	mut app := tea.new_program(mut petal_model)
	petal_model.app_send = app.send
	app.run() or { panic('something went wrong! ${err}') }
}
