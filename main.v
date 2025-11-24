module main

import tauraamui.bobatea as tea

fn main() {
	mut petal_model := PetalModel.new()
	mut app := tea.new_program(mut petal_model)
	app.run() or { panic('something went wrong! ${err}') }
}
