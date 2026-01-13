module main

import os
import tauraamui.bobatea as tea
import cfg

fn main() {
	theme_name := os.getenv("PETAL_THEME")
	config := cfg.Config.new(load_from_path: none).set_theme(theme_name)

	mut petal_model := PetalModel.new(config)
	mut app := tea.new_program(mut petal_model)
	petal_model.app_send = app.send
	app.run() or { panic('something went wrong! ${err}') }
}
