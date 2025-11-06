module main

import math
import tauraamui.bobatea as tea

const gitcommit_hash = $embed_file('.githash').to_string()

const version = 'pre-alpha-v0.0.0'
const build_id = gitcommit_hash

const logo_contents = $embed_file('./splash-logo.txt')

struct SplashLogo {
mut:
	data  []string
	width int
}

struct SplashScreenModel {
	leader_key string
	logo       SplashLogo
mut:
	leader_mode  bool
	leader_data  string
	dialog_model ?DebuggableModel
}

fn new_splash_screen_model() DebuggableModel {
	return SplashScreenModel{
		leader_key: ';'
		logo:       SplashLogo{
			data: logo_contents.to_string().split_into_lines()
		}
	}
}

fn (mut m SplashScreenModel) init() ?tea.Cmd {
	return none
}

fn (mut m SplashScreenModel) handle_escape() (tea.Model, ?tea.Cmd) {
	if !m.leader_mode {
		return SplashScreenModel{}, tea.quit
	}
	m.leader_mode = false
	m.leader_data = ''
	return m.clone(), none
}

fn (mut m SplashScreenModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	mut cmds := []tea.Cmd{}
	// handle dialog messages first
	match msg {
		CloseDialogMsg {
			m.dialog_model = none
		}
		else {}
	}

	if mut open_model := m.dialog_model {
		d, cmd := open_model.update(msg)
		if d is DebuggableModel {
			m.dialog_model = d
		}
		return m.clone(), cmd
	}

	match msg {
		tea.KeyMsg {
			match msg.k_type {
				.special {
					match msg.string() {
						'escape' {
							return m.handle_escape()
						}
						'ctrl+c' {
							return m.handle_escape()
						}
						else {}
					}
				}
				.runes {
					match m.leader_mode {
						true {
							m.leader_data += msg.string()
						}
						else {
							match msg.string() {
								'q' {
									return SplashScreenModel{}, tea.quit
								}
								m.leader_key {
									if !m.leader_mode {
										m.leader_mode = true
									}
								}
								else {}
							}
						}
					}
				}
			}
		}
		OpenDialogMsg {
			mut d_model := msg.model
			cmd := d_model.init()
			m.dialog_model = d_model
			u_cmd := cmd or { tea.noop_cmd }
			cmds << u_cmd
		}
		else {}
	}

	if m.leader_data == 'ff' {
		m.leader_mode = false
		m.leader_data = ''
		cmds << open_file_picker
	}

	return m.clone(), tea.batch_array(cmds)
}

fn (m SplashScreenModel) view(mut ctx tea.Context) {
	render_version_label(mut ctx, "${version} - (#${build_id})")
	render_logo_and_help_centered_and_stacked(mut ctx, m.logo, m.leader_mode, m.leader_data)
	render_help_keybinds(mut ctx)

	offset_from_id := ctx.push_offset(tea.Offset{ y: ctx.window_height() - 1 })
	defer { ctx.clear_offsets_from(offset_from_id) }
	ctx.set_color(tea.Color.ansi(249))
	ctx.draw_text(ctx.window_width() - tea.visible_len(m.leader_data) - 1, 0, m.leader_data)
	ctx.reset_color()

	ctx.clear_all_offsets()
	if mut open_model := m.dialog_model {
		open_model.view(mut ctx)
	}
}

fn render_version_label(mut ctx tea.Context, version_label string) {
	ctx.set_color(help_fg_color)
	ctx.draw_text(1, 0, version_label)
	ctx.reset_color()
}

fn render_help_keybinds(mut ctx tea.Context) {
	offset_from_id := ctx.push_offset(tea.Offset{ x: 1, y: ctx.window_height() - 1 })
	defer { ctx.clear_offsets_from(offset_from_id) }

	ctx.set_color(help_fg_color)
	ctx.draw_text(0, 0, 'q: quit ${dot} esc: exit')
	ctx.reset_color()
}

fn render_logo_and_help_centered_and_stacked(mut ctx tea.Context, logo SplashLogo, in_leader_mode bool, leader_data string) {
	// NOTE(tauraamui) [25/10/2025]: all following contents to be padded from top of window
	base_offset_y := f64(ctx.window_height()) * 0.1
	offset_from_id := ctx.push_offset(tea.Offset{
		x: ctx.window_width() / 2
		y: int(math.floor(base_offset_y))
	})
	defer { ctx.clear_offsets_from(offset_from_id) }

	ctx.push_offset(render_logo(mut ctx, logo))
	ctx.push_offset(render_lilly_name(mut ctx))
	ctx.push_offset(render_keybinds_list(mut ctx, in_leader_mode, leader_data))
	render_copyright_footer(mut ctx)
}

const petal_pink_color = tea.Color{
	r: 245
	g: 191
	b: 243
}

const petal_green_color = tea.Color{
	r: 97
	g: 242
	b: 136
}

const copyright_footer_label = 'the lilly editor authors © (made with ${[u8(0xf0), 0x9f, 0x92,
	0x95].bytestr()})'

fn render_copyright_footer(mut ctx tea.Context) {
	offset_from_id := ctx.push_offset(tea.Offset{
		x: -(tea.visible_len(copyright_footer_label) / 2)
		y: 1
	})
	defer { ctx.clear_offsets_from(offset_from_id) }
	ctx.set_color(petal_pink_color)
	ctx.draw_text(0, 0, copyright_footer_label)
	ctx.reset_color()
}

const help_fg_color = tea.Color.ansi(241)

const basic_command_help = [
	' Find File                   <leader>ff',
]

const disabled_command_help = [
	' Find Word                   <leader>fg',
	' Recent Files                <leader>fo',
	' File Browser                <leader>fv',
	' Colorschemes                <leader>cs',
	' New File                    <leader>nf',
]

const pending_match_color = tea.Color.ansi(244)
const closest_match_color = petal_green_color

fn render_keybinds_list(mut ctx tea.Context, in_leader_mode bool, leader_data string) tea.Offset {
	offset_from_id := ctx.push_offset(tea.Offset{ y: 1 })
	defer { ctx.clear_offsets_from(offset_from_id) }

	for l in basic_command_help {
		ctx.push_offset(tea.Offset{ y: 1 })
		ctx.push_offset(tea.Offset{ x: -(tea.visible_len(l) / 2) })
		if in_leader_mode {
			fg_color := if leader_data == 'f' { closest_match_color } else { pending_match_color }
			ctx.set_color(fg_color)
		}
		ctx.draw_text(0, 0, l)
		if in_leader_mode {
			ctx.reset_color()
		}
		ctx.pop_offset()
		ctx.push_offset(tea.Offset{ y: 1 })
	}

	for l in disabled_command_help {
		ctx.push_offset(tea.Offset{ y: 1 })
		ctx.push_offset(tea.Offset{ x: -(tea.visible_len(l) / 2) })
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

fn render_lilly_name(mut ctx tea.Context) tea.Offset {
	offset_from_id := ctx.push_offset(tea.Offset{})
	defer { ctx.clear_offsets_from(offset_from_id) }

	ctx.push_offset(tea.Offset{ y: 1 })
	version_label := 'lilly (project petal) ${[u8(0xf0), 0x9f, 0x8c, 0xb8].bytestr()}'

	first_version_label_offset_id := ctx.push_offset(tea.Offset{
		x: -(tea.visible_len(version_label) / 2)
	})
	ctx.draw_text(0, 0, version_label)

	ctx.clear_offsets_from(first_version_label_offset_id)
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
	ctx.set_color(petal_pink_color)
	offset_from_id := ctx.push_offset(tea.Offset{})
	defer { ctx.clear_offsets_from(offset_from_id) }
	for _, l in logo.data {
		// NOTE(tauraamui) [26/10/25] by splitting these offset pushes into two separate calls
		//                            we're only continuously removing the offset for the X position
		//                            each loop iter, so by the end `compact_offsets` is a combination of
		//                            the full height of the logo once its been completely rendered
		ctx.push_offset(tea.Offset{ y: 1 })
		ctx.push_offset(tea.Offset{ x: -(tea.visible_len(l) / 2) })
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
			ctx.set_color(petal_green_color)
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

fn (m SplashScreenModel) debug_data() DebugData {
	return DebugData{
		name: 'splash_screen data'
		data: {
			'leader key':   m.leader_key
			'': if d := m.dialog_model { d.debug_data() } else { 'null' }
		}
	}
}

fn (m SplashScreenModel) clone() tea.Model {
	return SplashScreenModel{
		...m
	}
}
