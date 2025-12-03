module main

import tauraamui.bobatea as tea

struct VersionModel {
	width   int
	height  int
	version string
}

fn open_version_dialog() tea.Msg {
	return OpenDialogMsg{
		model: VersionModel{
			width:  52
			height: 5
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
	r_ctx.draw_rect(0, 0, m.width, m.height)
	width  := m.width  - 2
	height := m.height - 2

	subtle_bordered_layout.size(m.width, m.height).render(mut r_ctx, fn [width, height] (mut ctx tea.Context) {
		ctx.reset_color()
		version_label := "project petal version (${version})"
		ctx.draw_text((width / 2) - tea.visible_len(version_label) / 2, height / 2, version_label)
	})
}

fn (m VersionModel) width() int { return m.width }

fn (m VersionModel) height() int { return m.height }

fn (m VersionModel) debug_data() DebugData {
	return DebugData{}
}

fn (m VersionModel) clone() tea.Model {
	return VersionModel{
		...m
	}
}


