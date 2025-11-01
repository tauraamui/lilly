module main

import tauraamui.bobatea as tea

const dot = "•"

struct PetalModel {
mut:
    active_screen DebuggableModel
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
			if msg.k_type == .special && msg.string() == "f12" {
				if !(m.active_screen is DebugScreenModel) {
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
		else {}
	}
	screen, cmds := m.active_screen.update(msg)
	if screen is DebuggableModel {
		m.active_screen = screen
	}
	return m.clone(), cmds
}

fn (m PetalModel) view(mut ctx tea.Context) {
    mut screen := m.active_screen
    screen.view(mut ctx)
}

fn (m PetalModel) clone() tea.Model {
    return PetalModel{
        ...m
    }
}

