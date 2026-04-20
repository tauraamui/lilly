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

module boba

import math
import time
import tauraamui.bobatea as tea

const frames_per_cycle = 50.0

pub type BorderedInputField = InputField

pub struct InputField {
mut:
	value              string
	width              int
	layout             tea.Layout = no_bordered_layout
	input_prefix       string     = '>'
	prefix_padding     int        = 1
	cursor_pos         int
	cursor_blink_frame int
	focused            bool
}

const no_bordered_layout = tea.new_layout()
	.border(.none)

pub fn BorderedInputField.new(border_color tea.Color) InputField {
	return InputField{
		layout: tea.new_layout().border(.normal).border_color(border_color)
	}
}

pub fn InputField.new() InputField {
	return InputField{}
}

pub fn InputField.new_with_prefix(input_prefix string, prefix_padding int) InputField {
	return InputField{
		input_prefix:   input_prefix
		prefix_padding: prefix_padding
	}
}

pub fn (mut i InputField) init() fn () tea.Msg {
	return cursor_blink_cmd()
}

pub struct CursorBlinkMsg {
pub:
	time time.Time
}

pub fn cursor_blink_cmd() tea.Cmd {
	return tea.tick(33 * time.millisecond, fn (t time.Time) tea.Msg {
		return CursorBlinkMsg{
			time: t
		}
	})
}

pub fn (mut m InputField) update(msg tea.Msg) (InputField, fn () tea.Msg) {
	if !m.focused && msg is tea.KeyMsg {
		return m.clone(), tea.noop_cmd
	}

	mut cmds := []tea.Cmd{}
	match msg {
		tea.KeyMsg {
			m.cursor_blink_frame = 0
			match msg.k_type {
				.special {
					match msg.string() {
						'left', 'ctrl+b' {
							if m.cursor_pos > 0 {
								m.cursor_pos--
							}
						}
						'right', 'ctrl+f' {
							if m.cursor_pos < m.rune_len() {
								m.cursor_pos++
							}
						}
						'home', 'ctrl+a' {
							m.cursor_pos = 0
						}
						'end', 'ctrl+e' {
							m.cursor_pos = m.rune_len()
						}
						'backspace' {
							if m.cursor_pos > 0 {
								runes := m.value_runes()
								m.value = (runes[..m.cursor_pos - 1].string()) +
									(runes[m.cursor_pos..].string())
								m.cursor_pos--
							}
						}
						'delete', 'ctrl+d' {
							if m.cursor_pos < m.rune_len() {
								runes := m.value_runes()
								m.value = (runes[..m.cursor_pos].string()) + (runes[m.cursor_pos +
									1..].string())
							}
						}
						else {}
					}
				}
				else {
					input_char := msg.string()
					runes := m.value_runes()
					m.value = (runes[..m.cursor_pos].string()) + input_char +
						(runes[m.cursor_pos..].string())
					m.cursor_pos += input_char.runes().len
				}
			}
		}
		CursorBlinkMsg {
			m.cursor_blink_frame = (m.cursor_blink_frame + 1) % int(frames_per_cycle)
			if m.focused {
				cmds << cursor_blink_cmd()
			}
		}
		tea.FocusedMsg {
			m.focused = true
			cmds << cursor_blink_cmd()
		}
		tea.BlurredMsg {
			m.focused = false
		}
		tea.ResizedMsg {
			m.width = msg.window_width
		}
		else {}
	}

	return m.clone(), tea.batch_array(cmds)
}

pub fn (m InputField) view(mut r_ctx tea.Context) {
	width := m.width
	// NOTE(tauraamui) [03/12/25]: don't render if has no width
	// let's also make sure we notice if width is ever negative
	// because that's a bug signifier
	assert !(width < 0)
	if width <= 0 {
		return
	}

	cursor_pos := m.cursor_pos
	cursor_color := calculate_cursor_color(m.cursor_blink_frame)
	value_runes := m.value_runes()
	input_prefix := m.input_prefix
	prefix_padding := m.prefix_padding

	height := if m.layout.border == .none { 1 } else { 3 }
	m.layout.size(width, height).render(mut r_ctx, fn [cursor_pos, cursor_color, width, value_runes, input_prefix, prefix_padding] (mut l_ctx tea.Context) {
		l_ctx.set_clip_area(tea.ClipArea{0, 0, width - 3, 1})
		defer { l_ctx.clear_clip_area() }

		left_right_border_cells_to_deduct_from_rects_full_width := 2
		l_ctx.clear_area(0, 0, width - left_right_border_cells_to_deduct_from_rects_full_width, 1)
		l_ctx.draw_text(0, 0, input_prefix)

		input_text_offset := l_ctx.push_offset(tea.Offset{
			x: prefix_padding + tea.visible_len(input_prefix)
		})
		cursor_within_content := cursor_pos < value_runes.len
		for i, r in value_runes {
			r_str := r.str()
			if cursor_within_content && i == cursor_pos {
				l_ctx.set_bg_color(cursor_color)
			}
			l_ctx.draw_text(0, 0, r_str)
			l_ctx.push_offset(tea.Offset{ x: tea.visible_len(r_str) })
			l_ctx.reset_bg_color()
		}

		if !cursor_within_content {
			l_ctx.set_bg_color(cursor_color)
			l_ctx.draw_rect(0, 0, 1, 1)
			l_ctx.reset_bg_color()
		}
		l_ctx.clear_from_offset(input_text_offset)
	})
}

fn calculate_cursor_color(blink_frame int) tea.Color {
	angle := f64(blink_frame) * 2.0 * math.pi / frames_per_cycle
	sine_value := math.sin(angle)
	color_range := 255 - 235
	color_value := 235 + int((sine_value + 1.0) * f64(color_range) / 2.0)
	return tea.Color.ansi(color_value)
}

pub fn (m &InputField) value() string {
	return m.value
}

pub fn (m &InputField) value_runes() []rune {
	return m.value.runes()
}

pub fn (m &InputField) rune_len() int {
	return m.value.runes().len
}

pub fn (mut m InputField) reset() {
	m.value = ''
	m.cursor_pos = 0
}

pub fn (mut m InputField) focus() {
	m.focused = true
}

pub fn (mut m InputField) blur() {
	m.focused = false
}

pub fn (m &InputField) focused() bool {
	return m.focused
}

fn (m InputField) clone() InputField {
	return InputField{
		...m
	}
}
