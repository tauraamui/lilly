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

import os
import bobatea as tea
import lib.petal.theme
import lib.cfg
import lib.palette
import lib.documents
import lib.clipboard

const dot = '•'

struct PetalModel {
mut:
	app_send                ?fn (tea.Msg)
	version                 string
	config                  cfg.Config @[required]
	theme                   theme.Theme
	first_frame             bool
	active_screen           DebuggableModel // all screens are debuggable to help with live, well... debugging
	clear_screen_next_frame bool
	logs                    []LogMsg
	last_resize_width       int
	last_resize_height      int
	golden_frames           GoldenFrameState
}

@[params]
struct PetalModelOptions {
	initial_file_path ?string
}

fn PetalModel.new(version string, config cfg.Config, doc_controller &documents.Controller, cb &clipboard.Manager, opts PetalModelOptions) PetalModel {
	return PetalModel{
		version:       version
		config:        config
		theme:         config.theme
		first_frame:   true
		active_screen: SplashScreenModel.new(
			version:           version
			leader_key:        config.leader_key
			theme:             config.theme
			doc_controller:    doc_controller
			cb:                cb
			initial_file_path: opts.initial_file_path
			expand_tabs:       config.expand_tabs
			tab_width:         config.tab_width
		)
		golden_frames: GoldenFrameState.init()
	}
}

fn (mut m PetalModel) init() fn () tea.Msg {
	return m.active_screen.init()
}

struct ToggleDebugScreenMsg {}

fn toggle_debug_screen() tea.Msg {
	return ToggleDebugScreenMsg{}
}

fn (mut m PetalModel) on_toggle_debug_screen() (tea.Model, fn () tea.Msg) {
	if m.active_screen !is DebugScreenModel {
		m.active_screen = DebugScreenModel.new(m.active_screen, m.logs, m.last_resize_width,
			m.last_resize_height)
	}
	return m.clone(), tea.noop_cmd
}

struct SwapActiveScreenMsg {
	screen DebuggableModel
}

fn swap_active_screen(screen DebuggableModel) tea.Cmd {
	return fn [screen] () tea.Msg {
		return SwapActiveScreenMsg{screen}
	}
}

struct CheckIfTMUXWrappedMsg {}

fn check_if_tmux_wrapped() tea.Msg {
	return CheckIfTMUXWrappedMsg{}
}

fn (mut m PetalModel) update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
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
		SwapActiveScreenMsg {
			mut screen := msg.screen
			cmds << screen.init()
			m.active_screen = screen
			return m.clone(), tea.batch_array(cmds)
		}
		LogMsg {
			m.logs << msg
		}
		tea.ResizedMsg {
			m.last_resize_width = msg.window_width
			m.last_resize_height = msg.window_height
		}
		QueryPWDGitBranchMsg {
			if send := m.app_send {
				spawn fn [send] () {
					branch := resolve_git_branch_name(os.execute)
					send(PWDGitBranchResultMsg{
						branch_name: branch
					})
				}()
			}
		}
		else {}
	}

	screen, active_cmds := m.active_screen.update(msg)
	if screen is DebuggableModel {
		m.active_screen = screen
	}
	cmds << active_cmds
	return m.clone(), tea.batch_array(cmds)
}

fn (mut m PetalModel) view(mut ctx tea.Context) {
	if m.first_frame {
		bg_color := m.theme.bg_color
		ctx.set_default_fg_color(palette.fg_color(bg_color))
		ctx.set_default_bg_color(bg_color)
		m.first_frame = false
	}
	mut screen := m.active_screen
	screen.view(mut ctx)
	m.golden_frames.capture(ctx)
}

fn (m PetalModel) clone() tea.Model {
	return PetalModel{
		...m
	}
}
