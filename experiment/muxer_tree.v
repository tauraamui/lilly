module main

import bobatea as tea

@[noinit]
struct AppModel {
}

fn AppModel.new() AppModel {
	return AppModel{}
}

fn (mut m AppModel) init() fn () tea.Msg {
	return tea.noop_cmd
}

fn (mut m AppModel) update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
	match msg {
		tea.KeyMsg {
			match msg.k_type {
				.special {
					if msg.string() == 'escape' { return m.clone(), tea.quit }
				}
				.runes {
					match msg.string() {
						'q' { return m.clone(), tea.quit }
						else {}
					}
				}
			}
		}
		else {}
	}
	return m.clone(), tea.noop_cmd
}

fn (m AppModel) view(mut ctx tea.Context) {
	split_tree_msg := 'split tree experiment render test'
	ctx.draw_text((ctx.window_width() / 2) - (tea.visible_len(split_tree_msg) / 2), ctx.window_height() / 2, split_tree_msg)
}

fn (m AppModel) clone() tea.Model {
	return AppModel{
		...m
	}
}

fn main() {
	mut app_model := AppModel.new()
	mut app := tea.new_program(mut app_model)
	app.run() or { panic('something went wrong!: ${err}') }
}
