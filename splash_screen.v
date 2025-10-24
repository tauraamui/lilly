module main

import tauraamui.bobatea as tea

struct SplashScreenModel {
}

fn new_splash_screen_model() SplashScreenModel {
    return SplashScreenModel{}
}

fn (mut m SplashScreenModel) init() ?tea.Cmd {
    return none
}

fn (mut m SplashScreenModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	match msg {
		tea.KeyMsg {
			match msg.code {
				.x {
					return SplashScreenModel{}, tea.quit
				}
				else {}
			}
		}
		else {}
	}

	return m.clone(), none
}

fn (m SplashScreenModel) view(mut ctx tea.Context) {
    ctx.draw_text(0, 0, "Lilly v2 (petal)")
}

fn (m SplashScreenModel) clone() tea.Model {
    return SplashScreenModel{
        ...m
    }
}

