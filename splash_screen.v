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
import bobatea as tea
import lib.cfg
import lib.palette
import lib.documents
import lib.clipboard

const gitcommit_hash = $embed_file('.githash').to_string()

fn build_id() string {
	$if golden_frames ? {
		return 'GITHASH'
	}
	return gitcommit_hash
}

const logo_contents = $embed_file('./splash-logo.txt')

// LogoColour selects which theme colour a run is drawn in. Runs carry a
// selector rather than a resolved tea.Color because the theme is a render-time
// input, so a cached colour would go stale.
enum LogoColour as u8 {
	pink
	green
}

// LogoRun is a stretch of one logo line drawn in a single colour, starting at
// visible column x. The logo's `g`/`p` colouring directives are already
// resolved: a directive's own cell is a space at the head of the run it opens.
struct LogoRun {
	x      int
	text   string
	colour LogoColour
}

// LogoLine is one prepared line of the logo.
struct LogoLine {
	visible_len int
	runs        []LogoRun
}

// SplashLogo holds the logo prepared for drawing. The preparation happens once,
// at construction, rather than per frame: scanning each line for directives and
// then drawing it one character at a time was the largest single source of
// allocation in the editor, and it ran on every frame the splash screen was
// visible - including every frame spent behind an open dialog.
struct SplashLogo {
	lines []LogoLine
	width int
}

// SplashLogo.parse splits the logo into coloured runs.
//
// Colour carries across lines. render_logo sets pink once before drawing and
// the directives mutate it as the logo is drawn top to bottom, so a line with
// no directive of its own inherits whatever colour the line above left set.
// Parsing therefore has to walk the lines in order, threading the colour
// through, which is also why it cannot be done a line at a time on demand.
fn SplashLogo.parse(contents string) SplashLogo {
	data := contents.split_into_lines()
	mut lines := []LogoLine{cap: data.len}
	mut colour := LogoColour.pink
	mut width := 0
	for line in data {
		mut runs := []LogoRun{}
		mut buf := []rune{}
		mut run_start := 0
		for i, r in line.runes() {
			if r == `g` || r == `p` {
				if buf.len > 0 {
					runs << LogoRun{
						x:      run_start
						text:   buf.string()
						colour: colour
					}
					buf = []rune{}
				}
				colour = if r == `g` { LogoColour.green } else { LogoColour.pink }
				// the directive occupies a cell, drawn blank in the colour it
				// just selected, which is what opens the next run
				run_start = i
				buf << ` `
				continue
			}
			if buf.len == 0 {
				run_start = i
			}
			buf << r
		}
		if buf.len > 0 {
			runs << LogoRun{
				x:      run_start
				text:   buf.string()
				colour: colour
			}
		}
		visible_len := tea.visible_len(line)
		if visible_len > width {
			width = visible_len
		}
		lines << LogoLine{
			visible_len: visible_len
			runs:        runs
		}
	}
	return SplashLogo{
		lines: lines
		width: width
	}
}

@[params]
struct SplashScreenOptions {
	config            cfg.Config
	version           string
	doc_controller    &documents.Controller
	doc_controller2   &documents.Controller2
	cb                &clipboard.Manager
	initial_file_path ?string
}

struct SplashScreenModel {
	config            cfg.Config
	version           string
	logo              SplashLogo
	doc_controller    &documents.Controller
	doc_controller2   &documents.Controller2
	cb                &clipboard.Manager
	initial_file_path ?string
mut:
	window_width  int
	window_height int
	tmux_wrapped  bool
	leader_mode   bool
	leader_data   string
	dialog_model  ?DebuggableModel
}

fn SplashScreenModel.new(opts SplashScreenOptions) SplashScreenModel {
	return SplashScreenModel{
		config:            opts.config
		version:           opts.version
		logo:              SplashLogo.parse(logo_contents.to_string())
		doc_controller:    opts.doc_controller
		doc_controller2:   opts.doc_controller2
		cb:                opts.cb
		initial_file_path: opts.initial_file_path
	}
}

fn (mut m SplashScreenModel) init() fn () tea.Msg {
	if file_path := m.initial_file_path {
		return tea.batch(check_if_tmux_wrapped, open_editor_workspace(file_path))
	}
	return check_if_tmux_wrapped
}

fn (mut m SplashScreenModel) handle_escape() (tea.Model, fn () tea.Msg) {
	if !m.leader_mode {
		return m.clone(), tea.quit
	}
	m.leader_mode = false
	m.leader_data = ''
	return m.clone(), tea.noop_cmd
}

fn (mut m SplashScreenModel) update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
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
		intercepted_msg := if msg is tea.ResizedMsg {
			tea.Msg(tea.ResizedMsg{
				window_width:  int(f64(msg.window_width) * 0.8)
				window_height: int(f64(msg.window_height) * 0.8)
			})
		} else {
			msg
		}

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
								m.config.leader_key {
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
			cmds << d_model.init()
			m.dialog_model = d_model
		}
		OpenFileMsg {
			cmds << open_editor_workspace(msg.file_path)
		}
		OpenEditorWorkspaceMsg {
			mut workspace := EditorWorkspaceModel2.new(EditorWorkspaceConfig.new(m.config),
				m.doc_controller2)
			/*
			workspace := EditorWorkspaceModel.new(
				version:           m.version
				ttheme:            m.theme
				leader_key:        m.leader_key
				initial_file_path: msg.initial_file_path
				doc_controller:    m.doc_controller
				doc_controller2:   m.doc_controller2
				clip_manager:      m.cb
				expand_tabs:       m.expand_tabs
				tab_width:         m.tab_width
			)
			*/
			cmds << swap_active_screen(workspace)
			cmds << open_file(msg.initial_file_path)
			return m.clone(), tea.sequence(...cmds)
		}
		CreateAndOpenFileMsg {
			cmds << open_editor_workspace(msg.path)
		}
		else {}
	}

	match m.leader_data {
		'ff' {
			m.reset_leader_mode()
			cmds << open_file_picker(m.config.theme)
		}
		'nf' {
			m.reset_leader_mode()
			cmds << open_new_file_dialog(m.config.theme)
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
	p_theme := m.config.theme
	render_version_label(mut ctx, '${m.version}', p_theme.subtle_light_grey)
	render_logo_and_help_centered_and_stacked(mut ctx,
		logo:                   m.logo
		in_leader_mode:         m.leader_mode
		leader_key:             m.config.leader_key
		leader_data:            m.leader_data
		petal_pink:             p_theme.petal_pink
		petal_green:            p_theme.petal_green
		closest_match_color:    p_theme.petal_green
		disabled_help_fg_color: p_theme.subtle_light_grey
	)
	render_help_keybinds(mut ctx, p_theme.subtle_light_grey)

	offset_from_id := ctx.push_offset(tea.Offset{ y: ctx.window_height() - 1 })
	defer { ctx.clear_offsets_from(offset_from_id) }
	if m.leader_mode {
		ctx.set_color(palette.subtle_text_fg_color)
		leader_data := m.config.leader_key + m.leader_data
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

const keybind_combo_column_start = 30

const basic_command_help_labels = [
	' Find File',
	' New File',
]!

const basic_command_help_combos = [
	'<leader>ff',
	'<leader>nf',
]!

const basic_command_help_suffixes = [
	'ff',
	'nf',
]!

const disabled_command_help = [
	' Find Word                   <leader>fg',
	' Recent Files                <leader>fo',
	' File Browser                <leader>fv',
	' Colorschemes                <leader>cs',
]!

fn format_keybind_help(label string, combo string) string {
	mut spacing := keybind_combo_column_start - tea.visible_len(label)
	if spacing < 1 {
		spacing = 1
	}
	return '${label}${' '.repeat(spacing)}${combo}'
}

// The help rows and their widths are fixed, so they are laid out once at
// startup rather than reformatted and re-measured on every frame.
const keybind_help_rows = build_keybind_help_rows()

const keybind_help_widths = measure_widths(keybind_help_rows)

const disabled_command_help_widths = measure_widths(disabled_command_help)

fn build_keybind_help_rows() []string {
	mut rows := []string{cap: basic_command_help_labels.len}
	for i, label in basic_command_help_labels {
		rows << format_keybind_help(label, basic_command_help_combos[i])
	}
	return rows
}

fn measure_widths(rows []string) []int {
	mut widths := []int{cap: rows.len}
	for r in rows {
		widths << tea.visible_len(r)
	}
	return widths
}

// keybinds_list_height is what the list advances the caller's cursor by. The
// original arrived at it by pushing a y offset both before and after every
// row, which double-spaced the list and left the sum as the return value.
const keybinds_list_height = 2 + (2 * (basic_command_help_labels.len + disabled_command_help.len))

const pending_match_color = tea.Color.ansi(244)

@[params]
struct RenderKeybindsListParams {
	in_leader_mode         bool
	leader_key             string
	leader_data            string
	closest_match_color    tea.Color
	disabled_help_fg_color tea.Color
}

// render_keybinds_list draws the help rows and returns the height it occupied.
//
// Rows are positioned by explicit coordinate for the same reason the logo is:
// the original pushed two offsets per row and never popped the vertical one,
// so the offset stack grew as the list was drawn and every subsequent draw paid
// to sum it. Rows land on odd rows, which is the double spacing the old
// push-before-and-after pattern produced.
fn render_keybinds_list(mut ctx tea.Context,
	opts RenderKeybindsListParams) tea.Offset {
	leader_key_label := "leader = '${opts.leader_key}'"
	ctx.draw_text(-(tea.visible_len(leader_key_label) / 2), 1, leader_key_label)

	mut y := 3
	for i, row in keybind_help_rows {
		if opts.in_leader_mode {
			suffix := basic_command_help_suffixes[i]
			if opts.leader_data.len > 0 && suffix.starts_with(opts.leader_data) {
				ctx.set_color(opts.closest_match_color)
			} else {
				ctx.set_color(pending_match_color)
			}
		}
		ctx.draw_text(-(keybind_help_widths[i] / 2), y, row)
		if opts.in_leader_mode {
			ctx.reset_color()
		}
		y += 2
	}

	ctx.set_style(.strikethrough)
	ctx.set_color(opts.disabled_help_fg_color)
	for i, row in disabled_command_help {
		ctx.draw_text(-(disabled_command_help_widths[i] / 2), y, row)
		y += 2
	}
	ctx.reset_color()
	ctx.clear_style()

	return tea.Offset{
		y: keybinds_list_height
	}
}

@[params]
struct RenderLogoParams {
	RenderLogoColoursParams
	logo SplashLogo
}

// render_logo draws the prepared logo, centred, and returns the offset the
// caller stacks the next block beneath.
//
// Every line is positioned by an explicit coordinate rather than by pushing an
// offset per line. draw_text resolves a position by summing the whole offset
// stack, so an offset per line made that stack grow as the logo was drawn and
// charged every later draw for it; the arithmetic is the same either way, and
// doing it here keeps the stack one deep.
fn render_logo(mut ctx tea.Context, opts RenderLogoParams) tea.Offset {
	// NOTE(tauraamui) [25/10/25]: this can be reduced to a style container which basically
	//                  makes the y offset be down by 10% of the parent. in this
	//                  case the parent is just the window itself, but could be anything
	offset_from_id := ctx.push_offset(tea.Offset{})
	defer { ctx.clear_offsets_from(offset_from_id) }

	mut colour := LogoColour.pink
	ctx.set_color(opts.petal_pink)
	for i, line in opts.logo.lines {
		centre := -(line.visible_len / 2)
		for run in line.runs {
			if run.colour != colour {
				colour = run.colour
				match colour {
					.pink { ctx.set_color(opts.petal_pink) }
					.green { ctx.set_color(opts.petal_green) }
				}
			}
			// y is i + 1 because the original pushed its first line offset
			// before drawing, putting the top line one row below the base
			ctx.draw_text(centre + run.x, i + 1, run.text)
		}
	}
	ctx.reset_color()
	return tea.Offset{
		y: opts.logo.lines.len
	}
}

// RenderLogoColoursParams carries the two theme colours the logo's runs are
// resolved against at draw time.
@[params]
struct RenderLogoColoursParams {
	petal_pink  tea.Color
	petal_green tea.Color
}

fn (m SplashScreenModel) debug_data() DebugData {
	return DebugData{
		name: 'splash_screen data'
		data: {
			'leader key':   m.config.leader_key
			'tmux wrapped': '${m.tmux_wrapped}'
			'':             if d := m.dialog_model { d.debug_data() } else { 'null' }
			'version':      '${m.version}'
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
