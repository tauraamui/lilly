// Copyright 2026 The Lilly Edtior contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

module main

import math
import os
import tauraamui.bobatea as tea
import palette
import lib.petal.theme
import lib.documents

const gitcommit_hash = $embed_file('.githash').to_string()

const version = 'pre-alpha-v0.0.0'
const build_id = gitcommit_hash

const logo_contents = $embed_file('./splash-logo.txt')

struct SplashLogo {
mut:
	data  []string
	width int
}

@[params]
struct SplashScreenOptions {
	leader_key     string
	theme          theme.Theme
	doc_controller &documents.Controller
}

struct SplashScreenModel {
	leader_key     string
	logo           SplashLogo
	theme          theme.Theme
	doc_controller &documents.Controller
mut:
	window_width int
	window_height int
	tmux_wrapped bool
	leader_mode  bool
	leader_data  string
	dialog_model ?DebuggableModel
}

fn SplashScreenModel.new(opts SplashScreenOptions) SplashScreenModel {
	return SplashScreenModel{
		leader_key:     opts.leader_key
		theme:          opts.theme
		logo:           SplashLogo{
			data: logo_contents.to_string().split_into_lines()
		}
		doc_controller: opts.doc_controller
	}
}

fn (mut m SplashScreenModel) init() ?tea.Cmd {
	return check_if_tmux_wrapped
}

fn (mut m SplashScreenModel) handle_escape() (tea.Model, ?tea.Cmd) {
	if !m.leader_mode {
		return m.clone(), tea.quit
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
		// force forward a 80% of the actual window size down to moddal model
		intercepted_msg := if msg is tea.ResizedMsg { tea.Msg(tea.ResizedMsg{
				window_width:  int(f64(msg.window_width) * 0.8)
				window_height: int(f64(msg.window_height) * 0.8)
			}) } else { msg }

		d, cmd := open_model.update(intercepted_msg)
		if d is DebuggableModel {
			m.dialog_model = d
		}
		return m.clone(), cmd
	}

	match msg {
		tea.ResizedMsg {
			m.window_width = msg.window_width
			m.window_height = msg.window_height
		}
		CheckIfTMUXWrappedMsg {
			m.tmux_wrapped = os.getenv('TMUX').len > 0
		}
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
						'ctrl+w+h' {
							$if !darwin {
								if m.tmux_wrapped {
									os.execute('tmux select-pane -L')
								}
							}
						}
						'ctrl+w+l' {
							$if !darwin {
								if m.tmux_wrapped {
									os.execute('tmux select-pane -R')
								}
							}
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
									return m.clone(), tea.quit
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
			if u_cmd := cmd {
				cmds << u_cmd
			}
		}
		OpenFileMsg {
			cmds << open_editor_workspace(msg.file_path)
		}
		OpenEditorWorkspaceMsg {
			mut workspace := EditorWorkspaceModel.new(m.theme, msg.initial_file_path,
				m.doc_controller)
			cmd := workspace.init()
			if u_cmd := cmd {
				cmds << u_cmd
			}
			return workspace, tea.batch_array(cmds)
		}
		else {}
	}

	match m.leader_data {
		'ff' {
			m.reset_leader_mode()
			cmds << open_file_picker(m.theme)
		}
		'xx' {
			m.reset_leader_mode()
			cmds << toggle_debug_screen
		}
		else {}
	}

	return m.clone(), tea.batch_array(cmds)
}

fn (mut m SplashScreenModel) reset_leader_mode() {
	m.leader_mode = false
	m.leader_data = ''
}

fn (m SplashScreenModel) view(mut ctx tea.Context) {
	render_version_label(mut ctx, '${version} - (#${build_id})', m.theme.subtle_light_grey)
	render_logo_and_help_centered_and_stacked(mut ctx,
		logo:                   m.logo
		in_leader_mode:         m.leader_mode
		leader_data:            m.leader_data
		petal_pink:             m.theme.petal_pink
		petal_green:            m.theme.petal_green
		closest_match_color:    m.theme.petal_green
		disabled_help_fg_color: m.theme.subtle_light_grey
	)
	render_help_keybinds(mut ctx, m.theme.subtle_light_grey)

	offset_from_id := ctx.push_offset(tea.Offset{ y: ctx.window_height() - 1 })
	defer { ctx.clear_offsets_from(offset_from_id) }
	if m.leader_mode {
		ctx.set_color(palette.subtle_text_fg_color)
		leader_data := m.leader_key + m.leader_data
		ctx.draw_text(ctx.window_width() - tea.visible_len(leader_data) - 1, 0, leader_data)
		ctx.reset_color()
	}

	ctx.clear_all_offsets()
	if mut open_model := m.dialog_model {
		id := ctx.push_offset(tea.Offset{
			x: int(f64(ctx.window_width() / 2)) - int(f64(open_model.width() / 2))
			y: int(f64(ctx.window_height() / 2)) - int(f64(open_model.height() / 2))
		})
		defer { ctx.clear_offsets_from(id) }

		open_model.view(mut ctx)
	}
}

fn render_version_label(mut ctx tea.Context, version_label string, help_fg_color tea.Color) {
	ctx.set_color(help_fg_color)
	ctx.draw_text(1, 0, version_label)
	ctx.reset_color()
}

fn render_help_keybinds(mut ctx tea.Context, help_fg_color tea.Color) {
	offset_from_id := ctx.push_offset(tea.Offset{ x: 1, y: ctx.window_height() - 1 })
	defer { ctx.clear_offsets_from(offset_from_id) }

	ctx.set_color(help_fg_color)
	ctx.draw_text(0, 0, 'q: quit ${dot} esc: exit')
	ctx.reset_color()
}

@[params]
struct RenderLogoAndHelpParams {
	RenderLogoParams
	RenderKeybindsListParams
}

fn render_logo_and_help_centered_and_stacked(mut ctx tea.Context,
	opts RenderLogoAndHelpParams) {
	// NOTE(tauraamui) [25/10/2025]: all following contents to be padded from top of window
	base_offset_y := f64(ctx.window_height()) * 0.1
	offset_from_id := ctx.push_offset(tea.Offset{
		x: ctx.window_width() / 2
		y: int(math.floor(base_offset_y))
	})
	defer { ctx.clear_offsets_from(offset_from_id) }

	ctx.push_offset(render_logo(mut ctx, opts.RenderLogoParams))
	ctx.push_offset(render_lilly_name(mut ctx))
	ctx.push_offset(render_keybinds_list(mut ctx, opts.RenderKeybindsListParams))
	render_copyright_footer(mut ctx, opts.petal_pink)
}

const copyright_footer_label = 'the lilly editor authors © (made with ${[u8(0xf0), 0x9f, 0x92,
	0x95].bytestr()})'

fn render_copyright_footer(mut ctx tea.Context, petal_pink tea.Color) {
	offset_from_id := ctx.push_offset(tea.Offset{
		x: -(tea.visible_len(copyright_footer_label) / 2)
		y: 1
	})
	defer { ctx.clear_offsets_from(offset_from_id) }
	ctx.set_color(petal_pink)
	ctx.draw_text(0, 0, copyright_footer_label)
	ctx.reset_color()
}

const basic_command_help = [
	' Find File                   <leader>ff',
]!

const disabled_command_help = [
	' Find Word                   <leader>fg',
	' Recent Files                <leader>fo',
	' File Browser                <leader>fv',
	' Colorschemes                <leader>cs',
	' New File                    <leader>nf',
]!

const pending_match_color = tea.Color.ansi(244)

@[params]
struct RenderKeybindsListParams {
	in_leader_mode         bool
	leader_data            string
	closest_match_color    tea.Color
	disabled_help_fg_color tea.Color
}

fn render_keybinds_list(mut ctx tea.Context,
	opts RenderKeybindsListParams) tea.Offset {
	offset_from_id := ctx.push_offset(tea.Offset{ y: 1 })
	defer { ctx.clear_offsets_from(offset_from_id) }

	for l in basic_command_help {
		ctx.push_offset(tea.Offset{ y: 1 })
		ctx.push_offset(tea.Offset{ x: -(tea.visible_len(l) / 2) })
		if opts.in_leader_mode {
			fg_color := if opts.leader_data == 'f' {
				opts.closest_match_color
			} else {
				pending_match_color
			}
			ctx.set_color(fg_color)
		}
		ctx.draw_text(0, 0, l)
		if opts.in_leader_mode {
			ctx.reset_color()
		}
		ctx.pop_offset()
		ctx.push_offset(tea.Offset{ y: 1 })
	}

	for l in disabled_command_help {
		ctx.push_offset(tea.Offset{ y: 1 })
		ctx.push_offset(tea.Offset{ x: -(tea.visible_len(l) / 2) })
		ctx.set_style(.strikethrough)
		ctx.set_color(opts.disabled_help_fg_color)
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

@[params]
struct RenderLogoParams {
	RenderLogoLineParams
	logo SplashLogo
}

fn render_logo(mut ctx tea.Context, opts RenderLogoParams) tea.Offset {
	// NOTE(tauraamui) [25/10/25]: this can be reduced to a style container which basically
	//                  makes the y offset be down by 10% of the parent. in this
	//                  case the parent is just the window itself, but could be anything

	// NOTE(tauraamui) [26/10/25]: basically each logo line by default renders as the full string per
	//                             line at once with the light pink color set, but some lines of the logo
	//                             contain both green and pink, so they need to be rendered per character
	//                             with the correct palette option/fg set
	// ctx.set_color(palette.petal_pink_color)
	ctx.set_color(opts.petal_pink)
	offset_from_id := ctx.push_offset(tea.Offset{})
	defer { ctx.clear_offsets_from(offset_from_id) }
	for _, l in opts.logo.data {
		// NOTE(tauraamui) [26/10/25] by splitting these offset pushes into two separate calls
		//                            we're only continuously removing the offset for the X position
		//                            each loop iter, so by the end `compact_offsets` is a combination of
		//                            the full height of the logo once its been completely rendered
		ctx.push_offset(tea.Offset{ y: 1 })
		ctx.push_offset(tea.Offset{ x: -(tea.visible_len(l) / 2) })
		render_logo_line(mut ctx, l, opts.RenderLogoLineParams)
		ctx.pop_offset()
	}
	ctx.reset_color()
	return ctx.compact_offsets_from(offset_from_id)
}

@[params]
struct RenderLogoLineParams {
	petal_pink  tea.Color
	petal_green tea.Color
}

fn render_logo_line(mut ctx tea.Context, line string, opts RenderLogoLineParams) {
	if has_colouring_directives(line) {
		render_logo_line_char_by_char(mut ctx, line, opts.petal_pink, opts.petal_green)
		return
	}
	ctx.draw_text(0, 0, line)
}

fn render_logo_line_char_by_char(mut ctx tea.Context,
	line string,
	petal_pink tea.Color,
	petal_green tea.Color) {
	for j, c in line.runes() {
		mut to_draw := '${c}'
		if to_draw == 'g' {
			to_draw = ' '
			ctx.set_color(petal_green)
		}
		if to_draw == 'p' {
			to_draw = ' '
			ctx.set_color(petal_pink)
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
			'tmux wrapped': '${m.tmux_wrapped}'
			'':             if d := m.dialog_model { d.debug_data() } else { 'null' }
			'version':      '${version} - (${build_id})'
		}
	}
}

fn (m SplashScreenModel) width() int {
	return m.window_width
}

fn (m SplashScreenModel) height() int {
	return m.window_height
}

fn (m SplashScreenModel) clone() tea.Model {
	return SplashScreenModel{
		...m
	}
}
