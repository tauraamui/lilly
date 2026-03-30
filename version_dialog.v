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

import tauraamui.bobatea as tea
import lib.petal.theme

struct VersionModel {
	version string
	theme   theme.Theme
	width   int
	height  int
}

fn open_version_dialog(version string, ttheme theme.Theme) tea.Cmd {
	return fn [version, ttheme] () tea.Msg {
		return OpenDialogMsg{
			model: VersionModel{
				version: version
				theme:  ttheme
				width:  52
				height: 5
			}
		}
	}
}

fn close_version_dialog() tea.Msg {
	return CloseDialogMsg{}
}

fn (mut m VersionModel) init() ?tea.Cmd {
	return none
}

fn (mut m VersionModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	match msg {
		tea.KeyMsg {
			match msg.k_type {
				.special {
					match msg.string() {
						'escape' {
							return m.clone(), close_version_dialog
						}
						'ctrl+c' {
							return m.clone(), close_version_dialog
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

fn (m VersionModel) view(mut r_ctx tea.Context) {
	r_ctx.clear_area(0, 0, m.width, m.height)
	width := m.width - 2
	height := m.height - 2
	version := m.version

	tea.new_layout().border(.normal).border_color(m.theme.petal_pink).size(m.width, m.height).render(mut r_ctx,
		fn [version, width, height] (mut ctx tea.Context) {
		ctx.reset_color()
		version_label := 'project petal version (${version})'
		ctx.draw_text((width / 2) - tea.visible_len(version_label) / 2, height / 2, version_label)
	})
}

fn (m VersionModel) width() int {
	return m.width
}

fn (m VersionModel) height() int {
	return m.height
}

fn (m VersionModel) debug_data() DebugData {
	return DebugData{}
}

fn (m VersionModel) clone() tea.Model {
	return VersionModel{
		...m
	}
}
