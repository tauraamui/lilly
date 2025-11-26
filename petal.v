module main

import tauraamui.bobatea as tea

const dot = '•'

struct PetalModel {
mut:
	theme_bg_color          ?tea.Color
	first_frame             bool
	active_screen           DebuggableModel // all screens are debuggable to help with live, well... debugging
	clear_screen_next_frame bool
	logs                    []string
	last_resize_width       int
	last_resize_height      int
}

fn PetalModel.new(theme_bg_color ?tea.Color) PetalModel {
	return PetalModel{
		theme_bg_color: theme_bg_color
		first_frame: true
		active_screen: SplashScreenModel.new()
	}
}

fn (mut m PetalModel) init() ?tea.Cmd {
	return none
}

struct ToggleDebugScreenMsg {}

fn toggle_debug_screen() tea.Msg {
	return ToggleDebugScreenMsg{}
}

fn (mut m PetalModel) on_toggle_debug_screen() (tea.Model, ?tea.Cmd) {
	if m.active_screen !is DebugScreenModel {
		m.active_screen = DebugScreenModel.new(m.active_screen, m.logs, m.last_resize_width,
			m.last_resize_height)
	}
	return m.clone(), none
}

fn (mut m PetalModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	mut cmds := []tea.Cmd{}
	match msg {
		tea.KeyMsg {
			if msg.k_type == .special && msg.string() == 'f12' {
				cmds << toggle_debug_screen
			}
		}
		ToggleDebugScreenMsg {
			return m.on_toggle_debug_screen()
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
	if m.first_frame {
		if bg_color := m.theme_bg_color {
			ctx.set_default_bg_color(bg_color)
		}
		m.first_frame = false
	}
	mut screen := m.active_screen
	screen.view(mut ctx)
}

fn (m PetalModel) clone() tea.Model {
	return PetalModel{
		...m
	}
}
