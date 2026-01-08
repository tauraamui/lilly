module main

import tauraamui.bobatea as tea
import cfg

fn main() {
	// config := cfg.Config.new(load_from_path: none).set_theme(cfg.light_theme_name)
	config := cfg.Config.new(load_from_path: none)

	mut petal_model := PetalModel.new(config)
	mut app := tea.new_program(mut petal_model)
	petal_model.app_send = app.send
	app.run() or { panic('something went wrong! ${err}') }
}
