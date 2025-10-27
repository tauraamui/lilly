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
				.escape {
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
	render_logo_and_help_centered_and_stacked(mut ctx, m.logo)
    render_help_keybinds(mut ctx)
}

fn render_logo_and_help_centered_and_stacked(mut ctx tea.Context, logo SplashLogo) {
    // NOTE(tauraamui) [25/10/2025]: all following contents to be padded from top of window
	base_offset_y := f64(ctx.window_height()) * 0.1
    offset_from_id := ctx.push_offset(tea.Offset{ x: ctx.window_width() / 2 y: int(math.floor(base_offset_y)) })
    defer { ctx.clear_offsets_from(offset_from_id) }

    ctx.push_offset(render_logo(mut ctx, logo))
    ctx.push_offset(render_version(mut ctx))
    ctx.push_offset(render_keybinds_list(mut ctx))
    render_copyright_footer(mut ctx)
}

fn render_help_keybinds(mut ctx tea.Context) {}

const petal_pink_color = tea.Color{ r: 245, g: 191, b: 243 }
const copyright_footer_label := 'the lilly editor authors ©'
fn render_copyright_footer(mut ctx tea.Context) {
	offset_from_id := ctx.push_offset(tea.Offset{ x: -(copyright_footer_label.len / 2), y: 1 })
	defer { ctx.clear_offsets_from(offset_from_id) }
	ctx.set_color(petal_pink_color)
	ctx.draw_text(0, 0, copyright_footer_label)
	ctx.reset_color()
}

const help_fg_color = tea.Color.ansi(241)

const basic_command_help := [
	' Find File                   <leader>ff',
]

const disabled_command_help := [
	' Find Word                   <leader>fg',
	' Recent Files                <leader>fo',
	' File Browser                <leader>fv',
	' Colorschemes                <leader>cs',
	' New File                    <leader>nf',
]

fn render_keybinds_list(mut ctx tea.Context) tea.Offset {
	offset_from_id := ctx.push_offset(tea.Offset{ y: 1 })
	defer { ctx.clear_offsets_from(offset_from_id) }

	for l in basic_command_help {
		ctx.push_offset(tea.Offset{ y: 1 })
		ctx.push_offset(tea.Offset{ x: -(l.runes().len / 2) })
		ctx.draw_text(0, 0, l)
		ctx.pop_offset()
		ctx.push_offset(tea.Offset{ y: 1 })
	}

	for l in disabled_command_help {
		ctx.push_offset(tea.Offset{ y: 1 })
		ctx.push_offset(tea.Offset{ x: -(l.runes().len / 2) })
		ctx.set_style(.strikethrough)
		ctx.set_color(help_fg_color)
		ctx.draw_text(0, 0, l)
		ctx.reset_color()
		ctx.clear_style()
		ctx.pop_offset()
		ctx.push_offset(tea.Offset{ y: 1 })
	}
	return ctx.compact_offsets_from(offset_from_id)
}

fn render_version(mut ctx tea.Context) tea.Offset {
    version_label := "lilly (project petal)"

	offset_from_id := ctx.push_offset(tea.Offset{})
	defer { ctx.clear_offsets_from(offset_from_id) }

	ctx.push_offset(tea.Offset{ y: 1 })
	ctx.push_offset(tea.Offset{ x: -(version_label.runes().len / 2) })
    ctx.draw_text(0, 0, version_label)
    ctx.pop_offset()
    return ctx.compact_offsets_from(offset_from_id)
}

fn render_logo(mut ctx tea.Context, logo SplashLogo) tea.Offset {
    // NOTE(tauraamui) [25/10/25]: this can be reduced to a style container which basically
    //                  makes the y offset be down by 10% of the parent. in this
    //                  case the parent is just the window itself, but could be anything

	// NOTE(tauraamui) [26/10/25]: basically each logo line by default renders as the full string per
	//                             line at once with the light pink color set, but some lines of the logo
	//                             contain both green and pink, so they need to be rendered per character
	//                             with the correct palette option/fg set
	ctx.set_color(r: 245, g: 191, b: 243)
	offset_from_id := ctx.push_offset(tea.Offset{})
	defer { ctx.clear_offsets_from(offset_from_id) }
	for _, l in logo.data {
		// NOTE(tauraamui) [26/10/25] by splitting these offset pushes into two separate calls
		//                            we're only continuously removing the offset for the X position
		//                            each loop iter, so by the end `compact_offsets` is a combination of
		//                            the full height of the logo once its been completely rendered
		ctx.push_offset(tea.Offset{ y: 1 })
	    ctx.push_offset(tea.Offset{ x: -(l.runes().len / 2) })
	    render_logo_line(mut ctx, l)
	    ctx.pop_offset()
	}
	ctx.reset_color()
	return ctx.compact_offsets_from(offset_from_id)
}

fn render_logo_line(mut ctx tea.Context, line string) {
	if has_colouring_directives(line) {
	    render_logo_line_char_by_char(mut ctx, line)
	    return
	}
    ctx.draw_text(0, 0, line)
}

fn render_logo_line_char_by_char(mut ctx tea.Context, line string) {
    for j, c in line.runes() {
        mut to_draw := '${c}'
        if to_draw == 'g' {
            to_draw = ' '
            ctx.set_color(r: 97, g: 242, b: 136)
        }
        if to_draw == 'p' {
            to_draw = ' '
            ctx.set_color(petal_pink_color)
        }
        ctx.draw_text(j, 0, to_draw)
    }
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

