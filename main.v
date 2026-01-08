module main

import tauraamui.bobatea as tea
import palette
import cfg
import theme

fn main() {
	config := cfg.Config.new(load_from_path: none).set_theme(theme.light_theme_name)

	mut petal_model := PetalModel.new(palette.theme_bg_color, palette.fg_color(palette.theme_bg_color), config)
	mut app := tea.new_program(mut petal_model)
	petal_model.app_send = app.send
	app.run() or { panic('something went wrong! ${err}') }
}
