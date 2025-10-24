module main

import tauraamui.bobatea as tea

struct PetalModel {
}

fn new_petal_model() PetalModel {
    return PetalModel{}
}

fn (mut m PetalModel) init() ?tea.Cmd {
    return none
}

fn (mut m PetalModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	match msg {
		tea.KeyMsg {
			match msg.code {
				.q {
					return PetalModel{}, tea.quit
				}
				else {}
			}
		}
		else {}
	}

	return m.clone(), none
}

fn (m PetalModel) view(mut ctx tea.Context) {
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

