module main

import tauraamui.bobatea as tea
import palette

fn main() {
	mut petal_model := PetalModel.new(palette.theme_bg_color)
	mut app := tea.new_program(mut petal_model)
	app.run() or { panic('something went wrong! ${err}') }
}
