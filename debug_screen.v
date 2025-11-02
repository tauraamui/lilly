module main

import rand
import tauraamui.bobatea as tea

interface DebuggableModel {
	tea.Model
	Debuggable
}

interface Debuggable {
	debug_data() []string
}

struct DebugScreenModel {
mut:
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
							w_model := m.wrapped_model
							if w_model is tea.Model {
								return m.clone(), close_debug(w_model)
							}
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
				.runes {
					match msg.string() {
						"q" {
							w_model := m.wrapped_model
							if w_model is tea.Model {
								return m.clone(), close_debug(w_model)
							}
						}
						else {}
					}
				}
			}
		}
		else {}
	}

	mut wrapped_model := m.wrapped_model
	wm, _ := wrapped_model.update(tea.NoopMsg{})
	if wm is DebuggableModel {
		m.wrapped_model = wm
	}
	return m.clone(), none
}

fn (mut m DebugScreenModel) view(mut ctx tea.Context) {
	katakana := "${generate_random_katakana()}"
	ctx.draw_text(0, 0, katakana)

	ctx.draw_text(0, 1, "${m.wrapped_model.debug_data()}")

	offset_from_id := ctx.push_offset(tea.Offset{ x: 1, y: ctx.window_height() - 1 })
	defer { ctx.clear_offsets_from(offset_from_id) }

	ctx.set_color(help_fg_color)
	ctx.draw_text(0, 0, "q ${dot} esc ${dot} f12: close")
	ctx.reset_color()
}

// generate_random_katakana generates a random Katakana character.
fn generate_random_katakana() rune {
	// Katakana block in Unicode ranges from U+30A0 to U+30FF.
	// We'll focus on the main range U+30A1 to U+30F6 (ァ to ヶ)
	// and exclude some less common/combining characters for simplicity.
	min_katakana := 0x30A1 // ァ
	max_katakana := 0x30F6 // ヶ

	// Generate a random integer within the Katakana range.
	// rand.int_in_range(min, max) includes both min and max.
	random_unicode_value := rand.int_in_range(min_katakana, max_katakana) or { min_katakana }

	return rune(random_unicode_value)
}


fn (m DebugScreenModel) debug_data() []string {
	return []
}

fn (m DebugScreenModel) clone() tea.Model {
	return DebugScreenModel{
		...m
	}
}

