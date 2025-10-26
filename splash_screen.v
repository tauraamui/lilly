module main

import math
import tauraamui.bobatea as tea

const logo_contents = $embed_file('./splash-logo.txt')

struct SplashLogo {
mut:
	data  []string
	width int
}

struct SplashScreenModel {
    logo SplashLogo
}

fn new_splash_screen_model() SplashScreenModel {
    return SplashScreenModel{
        logo: SplashLogo{
            data: logo_contents.to_string().split_into_lines()
        }
    }
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
    defer { ctx.clear_offsets() }
    // NOTE(tauraamui) [25/10/2025]: all following contents to be padded from top of window
    offset := render_logo(mut ctx, m.logo)
    render_version(mut ctx, offset)
    render_keybinds_list(mut ctx)
}

fn render_keybinds_list(mut ctx tea.Context) {
}

fn render_version(mut ctx tea.Context, offset tea.Offset) {
    defer { ctx.clear_offsets() }
    ctx.push_offset(offset)
    ctx.draw_text(0, 0, "lilly (project petal)")
}

fn render_logo(mut ctx tea.Context, logo SplashLogo) tea.Offset {
    defer { ctx.clear_offsets() }
    // NOTE(tauraamui) [25/10/25]: this can be reduced to a style container which basically
    //                  makes the y offset be down by 10% of the parent. in this
    //                  case the parent is just the window itself, but could be anything
	base_offset_y := f64(ctx.window_height()) * 0.1
    ctx.push_offset(tea.Offset{ y: int(math.floor(base_offset_y)) })

	offset_x := 0
	ctx.set_color(r: 245, g: 191, b: 243)
	for i, l in logo.data {
		start_x := offset_x + (ctx.window_width() / 2) - (l.runes().len / 2)
		assert start_x > 2
		if has_colouring_directives(l) {
			for j, c in l.runes() {
				mut to_draw := '${c}'
				if to_draw == 'g' {
					to_draw = ' '
					ctx.set_color(r: 97, g: 242, b: 136)
				}
				if to_draw == 'p' {
					to_draw = ' '
					ctx.set_color(r: 245, g: 191, b: 243)
				}
				ctx.draw_text(start_x + j, i, to_draw)
			}
			continue
		}
		ctx.draw_text(offset_x + (ctx.window_width() / 2) - (l.runes().len / 2), i, l)
	}
	ctx.reset_color()
	return ctx.compact_offsets()
}

fn has_colouring_directives(line string) bool {
	for c in line.split('') {
		if c == 'g' || c == 'p' {
			return true
		}
	}
	return false
}

fn (m SplashScreenModel) clone() tea.Model {
    return SplashScreenModel{
        ...m
    }
}

