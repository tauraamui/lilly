module main

import tauraamui.bobatea as tea

const dot = '•'

struct PetalModel {
mut:
	active_screen DebuggableModel // all screens are debuggable to help with live, well... debugging
	clear_screen_next_frame bool
}

fn new_petal_model() PetalModel {
	return PetalModel{
		active_screen: new_splash_screen_model()
	}
}

fn (mut m PetalModel) init() ?tea.Cmd {
	return tea.emit_resize
}

fn (mut m PetalModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	match msg {
		tea.KeyMsg {
			if msg.k_type == .special && msg.string() == 'f12' {
				if m.active_screen !is DebugScreenModel {
					m.active_screen = new_debug_screen_model(m.active_screen)
					return m.clone(), none
				}
			}
		}
		CloseDebugScreenMsg {
			screen := msg.prev_model
			if screen is DebuggableModel {
				m.active_screen = screen
			}
		}
		tea.ResizedMsg { m.clear_screen_next_frame = true }
		else {}
	}
	screen, cmds := m.active_screen.update(msg)
	if screen is DebuggableModel {
		m.active_screen = screen
	}
	return m.clone(), cmds
}

fn (mut m PetalModel) view(mut ctx tea.Context) {
	if m.clear_screen_next_frame {
		ctx.reset_bg_color()
		ctx.draw_rect(0, 0, ctx.window_width(), ctx.window_height())
		m.clear_screen_next_frame = false
	}
	mut screen := m.active_screen
	screen.view(mut ctx)
}

fn (m PetalModel) clone() tea.Model {
	return PetalModel{
		...m
	}
}
