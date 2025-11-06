module main

import rand
import strings
import tauraamui.bobatea as tea

interface DebuggableModel {
	tea.Model
	Debuggable
}

interface Debuggable {
	debug_data() DebugData
}

type DebugValue = string | DebugData

struct DebugData {
	name string
	data map[string]DebugValue
}

const debug_data_indent_amount := 4

fn (d DebugData) draw(mut ctx tea.Context, x int, y int, clear_offsets bool) {
	ctx.draw_text(x, y, '${d.name}: {')
	offset_from_id := ctx.push_offset(tea.Offset{ y: 1 })
	for k, v in d.data {
		match v {
			string {
				if k.len > 0 {
					ctx.draw_text(x + debug_data_indent_amount, y, "${k}: ${v}")
					ctx.push_offset(tea.Offset{ y: 1 })
				}
			}
			DebugData {
				v.draw(mut ctx, x + debug_data_indent_amount, y, false)
				ctx.push_offset(tea.Offset{ y: 1 })
			}
		}
	}
	ctx.draw_text(x, y, '}')
	if clear_offsets {
		ctx.clear_offsets_from(offset_from_id)
	}
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
		return CloseDebugScreenMsg{prev_model}
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
						'escape' {
							w_model := m.wrapped_model
							if w_model is tea.Model {
								return m.clone(), close_debug(w_model)
							}
						}
						'ctrl+c' {
							w_model := m.wrapped_model
							if w_model is tea.Model {
								return m.clone(), close_debug(w_model)
							}
						}
						'f12' {
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
						'q' {
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
	katakana := generate_decorator_label(ctx.window_width() / 6)
	ctx.set_color(help_fg_color)
	ctx.draw_text(0, 0, katakana)
	ctx.draw_text(ctx.window_width() - tea.visible_len(katakana), 0, katakana)
	ctx.reset_color()
	ctx.set_color(tea.Color.ansi(69))
	debug_label := '*********** debug screen ***********'
	ctx.draw_text((ctx.window_width() / 2) - tea.visible_len(debug_label) / 2, 0, debug_label)
	ctx.reset_color()

	m.wrapped_model.debug_data().draw(mut ctx, 0, 2, true)

	top_to_bottom_offset_id := ctx.push_offset(tea.Offset{ x: 1, y: ctx.window_height() - 1 })
	defer { ctx.clear_offsets_from(top_to_bottom_offset_id) }

	ctx.set_color(help_fg_color)
	ctx.draw_text(0, 0, 'q ${dot} esc ${dot} f12: close')
	ctx.reset_color()
}

fn generate_decorator_label(length int) string {
	mut sb := strings.new_builder(length)
	for _ in 0 .. length {
		sb.write_rune(generate_random_katakana())
	}
	return sb.str()
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

fn (m DebugScreenModel) debug_data() DebugData {
	return DebugData{}
}

fn (m DebugScreenModel) clone() tea.Model {
	return DebugScreenModel{
		...m
	}
}
