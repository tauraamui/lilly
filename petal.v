module main

import tauraamui.bobatea as tea

const dot = '•'

struct PetalModel {
mut:
	active_screen           DebuggableModel // all screens are debuggable to help with live, well... debugging
	clear_screen_next_frame bool
	logs                    []string
	last_resize_width int
	last_resize_height int
}

fn new_petal_model() PetalModel {
	return PetalModel{
		active_screen: new_splash_screen_model()
	}
}

fn (mut m PetalModel) init() ?tea.Cmd {
	return none
}

fn (mut m PetalModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	mut cmds := []tea.Cmd{}
	match msg {
		tea.KeyMsg {
			if msg.k_type == .special && msg.string() == 'f12' {
				if m.active_screen !is DebugScreenModel {
					m.active_screen = new_debug_screen_model(m.active_screen, m.logs, m.last_resize_width, m.last_resize_height)
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
		DebugLogMsg {
			m.logs << msg.message
		}
		tea.ResizedMsg {
			m.last_resize_width = msg.window_width
			m.last_resize_height = msg.window_height
		}
		else {}
	}
	screen, active_cmds := m.active_screen.update(msg)
	if screen is DebuggableModel {
		m.active_screen = screen
	}
	if a_cmds := active_cmds {
		cmds << a_cmds
	}
	return m.clone(), tea.batch_array(cmds)
}

fn (mut m PetalModel) view(mut ctx tea.Context) {
	mut screen := m.active_screen
	screen.view(mut ctx)
}

fn (m PetalModel) clone() tea.Model {
	return PetalModel{
		...m
	}
}
