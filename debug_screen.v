module main

import tauraamui.bobatea as tea

interface DebuggableModel {
	tea.Model
	Debuggable
}

interface Debuggable {
	debug_data() []string
}

struct DebugScreenModel {
	wrapped_model DebuggableModel
}

struct CloseDebugScreenMsg {
	prev_model tea.Model
}

fn close_debug(prev_model tea.Model) tea.Cmd {
	return fn [prev_model] () tea.Msg {
		return CloseDebugScreenMsg{ prev_model }
	}
}

fn new_debug_screen_model(wrapped_model DebuggableModel) DebugScreenModel {
	return DebugScreenModel{
		wrapped_model: wrapped_model
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
							w_model := m.wrapped_model
							if w_model is tea.Model {
								return m.clone(), close_debug(w_model)
							}
						}
						"f12" {
							w_model := m.wrapped_model
							if w_model is tea.Model {
								return m.clone(), close_debug(w_model)
							}
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
	ctx.draw_text(0, 0, "DEBUG MODE, 世界")

	ctx.draw_text(0, 1, "${m.wrapped_model.debug_data()}")

	offset_from_id := ctx.push_offset(tea.Offset{ x: 1, y: ctx.window_height() - 1 })
	defer { ctx.clear_offsets_from(offset_from_id) }

	ctx.set_color(help_fg_color)
	ctx.draw_text(0, 0, "esc ${dot} f12: close")
	ctx.reset_color()
}

fn (m DebugScreenModel) debug_data() []string {
	return []
}

fn (m DebugScreenModel) clone() tea.Model {
	return DebugScreenModel{
		...m
	}
}

