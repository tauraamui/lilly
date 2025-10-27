module main

import tauraamui.bobatea as tea

enum State as u8 {
    splash_screen
}

struct PetalModel {
mut:
    state State
    splash_screen SplashScreenModel
}

fn new_petal_model() PetalModel {
    return PetalModel{
        splash_screen: new_splash_screen_model()
    }
}

fn (mut m PetalModel) init() ?tea.Cmd {
    return none
}

fn (mut m PetalModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	mut cmds := []tea.Cmd{}

	match msg {
		tea.KeyMsg {
			match m.state {
			    .splash_screen {
			        s, cmd := m.splash_screen.update(msg)
			        if s is SplashScreenModel {
			            m.splash_screen = s
			        }
			        u_cmd := cmd or { tea.noop_cmd }
                    cmds << u_cmd
			    }
			}
		}
		else {}
	}

	return m.clone(), tea.batch_array(cmds)
}

fn (m PetalModel) view(mut ctx tea.Context) {
    if m.state == .splash_screen {
        m.splash_screen.view(mut ctx)
        return
    }
    window_width := ctx.window_width()
    window_height := ctx.window_height()

    title := "Petal Text Editor"

    ctx.draw_text((window_width / 2) - title.len / 2, window_height / 2, title)
}

fn (m PetalModel) clone() tea.Model {
    return PetalModel{
        ...m
    }
}

