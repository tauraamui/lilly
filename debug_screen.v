// Copyright 2026 The Lilly Edtior contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

module main

import rand
import strings
import bobatea as tea
import lib.boba
import lib.palette

interface DebuggableModel {
	tea.Model
	Debuggable
	width() int
	height() int
}

interface Debuggable {
	debug_data() DebugData
}

type DebugValue = string | DebugData

struct DebugData {
	name string
	data map[string]DebugValue
}

const debug_data_indent_amount = 4

fn (d DebugData) draw(mut ctx tea.Context, x int, y int, clear_offsets bool) {
	ctx.draw_text(x, y, '${d.name}: {')
	offset_from_id := ctx.push_offset(tea.Offset{ y: 1 })
	for k, v in d.data {
		match v {
			string {
				if k.len > 0 {
					ctx.draw_text(x + debug_data_indent_amount, y, '${k}: ${v}')
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

enum LogLevel {
	debug
	info
	warn
	error
}

fn (l LogLevel) str() string {
	return match l {
		.debug { 'DEBU' }
		.info { 'INFO' }
		.warn { 'WARN' }
		.error { 'ERRO' }
	}
}

fn (l LogLevel) fg() tea.Color {
	return match l {
		.debug { tea.Color.ansi(62) }
		.info { tea.Color.ansi(183) }
		.warn { tea.Color.ansi(220) }
		.error { tea.Color.ansi(162) }
	}
}

struct LogMsg {
	level   LogLevel
	message string
}

fn log(message string, level LogLevel) tea.Msg {
	return LogMsg{level, message}
}

fn debug_log(message string) tea.Cmd {
	return fn [message] () tea.Msg {
		return log(message, .debug)
	}
}

fn error_log(message string) tea.Cmd {
	return fn [message] () tea.Msg {
		return log(message, .error)
	}
}

enum ScreenState as u8 {
	data
	logs
}

struct DebugScreenModel {
	logs []LogMsg
mut:
	state              ScreenState
	wrapped_model      DebuggableModel
	window_width       int
	window_height      int
	last_resize_width  int
	last_resize_height int
}

struct CloseDebugScreenMsg {
	prev_model tea.Model
}

fn close_debug(prev_model tea.Model) tea.Cmd {
	return fn [prev_model] () tea.Msg {
		return CloseDebugScreenMsg{prev_model}
	}
}

fn DebugScreenModel.new(wrapped_model DebuggableModel, logs []LogMsg, last_resize_width int, last_resize_height int) DebugScreenModel {
	return DebugScreenModel{
		wrapped_model:      wrapped_model
		logs:               logs
		last_resize_width:  last_resize_width
		last_resize_height: last_resize_height
	}
}

fn (mut m DebugScreenModel) init() fn () tea.Msg {
	return tea.noop_cmd
}

fn (mut m DebugScreenModel) update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
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
						'1' {
							m.state = .data
						}
						'2' {
							m.state = .logs
						}
						else {}
					}
				}
			}
		}
		tea.ResizedMsg {
			m.last_resize_width = msg.window_width
			m.last_resize_height = msg.window_height
		}
		boba.CursorBlinkMsg {
			mut wrapped_model := m.wrapped_model
			wm, cmd := wrapped_model.update(msg)
			if wm is DebuggableModel {
				m.wrapped_model = wm
			}
			return m.clone(), cmd
		}
		else {}
	}

	mut wrapped_model := m.wrapped_model
	wm, _ := wrapped_model.update(tea.NoopMsg{})
	if wm is DebuggableModel {
		m.wrapped_model = wm
	}
	return m.clone(), tea.noop_cmd
}

fn (mut m DebugScreenModel) view(mut ctx tea.Context) {
	m.window_width = ctx.window_width()
	m.window_height = ctx.window_height()
	katakana := generate_decorator_label(ctx.window_width() / 6)

	ctx.set_color(palette.subtle_text_fg_color)
	ctx.draw_text(0, 0, katakana)
	ctx.draw_text(ctx.window_width() - tea.visible_len(katakana), 0, katakana)
	ctx.reset_color()

	ctx.set_color(palette.debug_header_color)
	debug_label := '*********** debug screen ***********'
	ctx.draw_text((ctx.window_width() / 2) - tea.visible_len(debug_label) / 2, 0, debug_label)
	ctx.reset_color()

	match m.state {
		.data {
			m.debug_data().draw(mut ctx, 0, 2, true)
		}
		.logs {
			ctx.draw_text((ctx.window_width() / 2) - tea.visible_len('LOGS') / 2, 2, 'LOGS')
			render_logs(mut ctx, 0, 4, m.logs)
		}
	}

	top_to_bottom_offset_id := ctx.push_offset(tea.Offset{ x: 1, y: ctx.window_height() - 1 })
	defer { ctx.clear_offsets_from(top_to_bottom_offset_id) }
	ctx.set_color(palette.help_fg_color)
	ctx.draw_text(0, 0, 'q ${dot} esc ${dot} f12: close')
	ctx.reset_color()
}

fn render_logs(mut ctx tea.Context, x int, y int, logs []LogMsg) {
	for i, l in logs {
		level_label := l.level.str()
		ctx.set_color(l.level.fg())

		mut label_x_offset := 0
		ctx.draw_text(x + label_x_offset, y + i, '[')
		label_x_offset += 1
		ctx.draw_text(x + label_x_offset, y + i, level_label)
		label_x_offset += tea.visible_len(level_label)
		ctx.draw_text(x + label_x_offset, y + i, ']')
		label_x_offset += 1
		ctx.reset_color()
		label_x_offset += 1 // single space padding
		ctx.draw_text(x + label_x_offset, y + i, l.message)
	}
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
	return DebugData{
		name: 'debug_screen data'
		data: {
			'current width':           '${m.window_width}'
			'current height':          '${m.window_height}'
			'last resized msg width':  '${m.last_resize_width}'
			'last resized msg height': '${m.last_resize_height}'
			'':                        m.wrapped_model.debug_data()
		}
	}
}

fn (m DebugScreenModel) width() int {
	return m.window_width
}

fn (m DebugScreenModel) height() int {
	return m.window_height
}

fn (m DebugScreenModel) clone() tea.Model {
	return DebugScreenModel{
		...m
	}
}
