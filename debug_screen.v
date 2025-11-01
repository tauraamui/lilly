module main

import tauraamui.bobatea as tea

struct DebugScreenModel {
	prev_model tea.Model
}

struct CloseDebugScreenMsg {
	prev_model tea.Model
}

fn close_debug(prev_model tea.Model) tea.Cmd {
	return fn [prev_model] () tea.Msg {
		return CloseDebugScreenMsg{ prev_model }
	}
}

fn new_debug_screen_model(prev_model tea.Model) DebugScreenModel {
	return DebugScreenModel{
		prev_model: prev_model
	}
}

fn (mut m DebugScreenModel) init() ?tea.Cmd {
    return none
}

fn (mut m DebugScreenModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	match msg {
		tea.KeyMsg {
			match msg.k_type {
				.special {
					match msg.string() {
						"escape" {
							return m.clone(), tea.quit
						}
						"ctrl+c" {
							return m.clone(), close_debug(m.prev_model)
						}
						else {}
					}
				}
				else {}
			}
		}
		else {}
	}

	return m.clone(), none
}

fn (mut m DebugScreenModel) view(mut ctx tea.Context) {
	ctx.draw_text(0, 0, "DEBUG MODE")
}

fn (m DebugScreenModel) clone() tea.Model {
	return DebugScreenModel{
		...m
	}
}

