module main

import os
import tauraamui.bobatea as tea
import palette
import glyphs

struct EditorWorkspaceModel {
	initial_file_path string
mut:
	mode               Mode
	dialog_model       ?DebuggableModel
	active_editor      ?DebuggableModel
	active_editor_data ?EditorData
	branch_name        string
	leader_suffix      string
	pending_command    string
}

struct OpenFileMsg {
	file_path string
}

fn open_file(file_path string) tea.Cmd {
	return fn [file_path] () tea.Msg {
		return OpenFileMsg{file_path}
	}
}

struct OpenEditorWorkspaceMsg {
	initial_file_path string
}

fn open_editor_workspace(initial_file_path string) tea.Cmd {
	return fn [initial_file_path] () tea.Msg {
		return OpenEditorWorkspaceMsg{initial_file_path}
	}
}

fn EditorWorkspaceModel.new(initial_file_path string) EditorWorkspaceModel {
	return EditorWorkspaceModel{
		initial_file_path: initial_file_path
	}
}

fn (mut m EditorWorkspaceModel) init() ?tea.Cmd {
	return tea.batch(open_editor(m.initial_file_path), query_editor_data, query_pwd_git_branch)
}

struct ToggleLeaderModeMsg {}

fn toggle_leader_mode() tea.Msg {
	return ToggleLeaderModeMsg{}
}

struct QueryPWDGitBranchMsg {}

fn query_pwd_git_branch() tea.Msg {
	return QueryPWDGitBranchMsg{}
}

struct PWDGitBranchResultMsg {
	branch_name string
}

fn pwd_git_branch_name(branch_name string) tea.Cmd {
	return fn [branch_name] () tea.Msg {
		return PWDGitBranchResultMsg{branch_name}
	}
}

fn resolve_git_branch_name(execute fn (cmd string) os.Result) string {
	prefix := '\uE0A0'
	wt := spawn currently_in_worktree(execute)
	in_wt := wt.wait()
	if in_wt {
		gb := spawn get_branch(execute)
		branch := gb.wait()
		return '${prefix} ${branch}'
	}
	return ''
}

fn currently_in_worktree(execute fn (cmd string) os.Result) bool {
	res := execute('git rev-parse --is-inside-work-tree')
	return res.exit_code == 0
}

fn get_branch(execute fn (cmd string) os.Result) string {
	res := execute('git branch --show-current')
	return res.output
}

fn (mut m EditorWorkspaceModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	mut cmds := []tea.Cmd{}

	// ***** dialog related state *****
	match msg {
		CloseDialogMsg {
			m.dialog_model = none
		}
		else {}
	}

	if mut open_model := m.dialog_model {
		intercepted_msg := if msg is tea.ResizedMsg { tea.Msg(
			// force forward a 80% of the actual window size down to moddal model
			tea.ResizedMsg{
				window_width: int(f64(msg.window_width) * 0.8)
				window_height: int(f64(msg.window_height) * 0.8)
			}
		) } else { msg }

		d, cmd := open_model.update(intercepted_msg)
		if d is DebuggableModel {
			m.dialog_model = d
		}
		return m.clone(), cmd
	}
	// ********

	match m.mode {
		.leader {
			if msg is tea.KeyMsg {
				match msg.k_type {
					.special {
						if msg.string() == 'escape' {
							m.mode = .normal
							m.leader_suffix = ''
						}
					}
					.runes {
						m.leader_suffix += msg.string()
					}
				}
			}
		}
		.normal {
			if msg is tea.KeyMsg && msg.k_type == .runes {
				match msg.string() {
					';' {
						m.mode = .leader
						return m.clone(), none
					}
					':' {
						m.mode = .command
						return m.clone(), none
					}
					else {}
				}
			}
		}
		.command {
			if msg is tea.KeyMsg {
				match msg.k_type {
					.special {
						match msg.string() {
							'escape' {
								m.mode = .normal
								m.pending_command = ''
								return m.clone(), none
							}
							'enter' {
								m.mode = .normal
								// TODO(tauraamui): emit action msg with command contents instead
								match m.pending_command {
									'q' {
										return m.clone(), tea.quit
									}
									'debug' {
										cmds << toggle_debug_screen
									}
									else {}
								}
								m.pending_command = ''
							}
							else {}
						}
					}
					.runes {
						m.pending_command += msg.string()
					}
				}
			}
		}
		else {}
	}

	if !(m.mode == .leader || m.mode == .command) {
		if mut active_editor := m.active_editor {
			e, cmd := active_editor.update(msg)
			if e is DebuggableModel {
				m.active_editor = e
			}
			u_cmd := cmd or { tea.noop_cmd }
			cmds << u_cmd
		}
	}

	match msg {
		tea.FocusedMsg {
			cmds << query_pwd_git_branch
		}
		OpenDialogMsg {
			mut d_model := msg.model
			cmd := d_model.init()
			m.dialog_model = d_model
			u_cmd := cmd or { tea.noop_cmd }
			cmds << u_cmd
		}
		OpenFileMsg {
			cmds << open_editor(msg.file_path)
			cmds << query_editor_data
			cmds << query_pwd_git_branch
		}
		OpenEditorMsg {
			mut e_model := EditorModel.new(msg.file_path)
			cmd := e_model.init()
			m.active_editor = e_model
			u_cmd := cmd or { tea.noop_cmd }
			cmds << u_cmd
		}
		EditorDataResultMsg {
			m.active_editor_data = msg.data
		}
		PWDGitBranchResultMsg {
			m.branch_name = msg.branch_name
		}
		ToggleLeaderModeMsg {
			m.mode = .leader
		}
		else {}
	}

	match m.leader_suffix {
		'ff' {
			m.leader_suffix = ''
			m.mode = .normal
			cmds << open_file_picker
		}
		else {}
	}

	return m.clone(), tea.batch_array(cmds)
}

fn (m EditorWorkspaceModel) view(mut ctx tea.Context) {
	if mut active_editor := m.active_editor {
		active_editor.view(mut ctx)
	}

	m.render_status_bar(mut ctx)

	if mut open_model := m.dialog_model {
		ten_percent_width := int(f64(ctx.window_width()) * 0.1)
		ten_percent_height := int(f64(ctx.window_height()) * 0.1)

		id := ctx.push_offset(tea.Offset{
			x: ten_percent_width
			y: ten_percent_height
		})
		defer { ctx.clear_offsets_from(id) }

		open_model.view(mut ctx)
	}
}

fn (m EditorWorkspaceModel) render_status_bar(mut ctx tea.Context) {
	ctx.set_bg_color(palette.status_bar_bg_color)
	ctx.draw_rect(0, ctx.window_height() - 2, ctx.window_width(), 1)
	ctx.reset_bg_color()

	m.render_status_blocks(mut ctx)
	m.render_leader_or_command_user_input_text(mut ctx)
}

fn (m EditorWorkspaceModel) render_status_blocks(mut ctx tea.Context) {
	status_bar_offset := ctx.push_offset(tea.Offset{ y: ctx.window_height() - 2 })
	defer { ctx.clear_offsets_from(status_bar_offset) }

	ctx.set_color(m.mode.color())
	ctx.draw_text(0, 0, '${glyphs.left_rounded}${glyphs.block}')
	ctx.reset_color()
	blocks_offset := ctx.push_offset(tea.Offset{ x: 2 })

	mode_label := m.mode.str()
	ctx.set_color(palette.matte_black_fg_color)
	ctx.set_bg_color(m.mode.color())
	ctx.draw_text(0, 0, mode_label)
	ctx.reset_bg_color()
	ctx.reset_color()

	ctx.push_offset(tea.Offset{ x: tea.visible_len(mode_label) })

	ctx.set_color(m.mode.color())
	ctx.draw_text(0, 0, '${glyphs.block}${glyphs.slant_right_flat_bottom}')
	ctx.reset_color()
	ctx.push_offset(tea.Offset{ x: 2 })

	ctx.set_color(palette.status_file_name_bg_color)
	ctx.draw_text(0, 0, '${glyphs.slant_left_flat_top}${glyphs.block}')
	ctx.reset_color()
	ctx.push_offset(tea.Offset{ x: 2 })

	file_name_label := m.active_file_name()
	ctx.set_color(palette.matte_white_fg_color)
	ctx.set_bg_color(palette.status_file_name_bg_color)
	ctx.draw_text(0, 0, file_name_label)
	ctx.reset_bg_color()
	ctx.reset_color()

	ctx.push_offset(tea.Offset{ x: tea.visible_len(file_name_label) })

	ctx.set_color(palette.status_file_name_bg_color)
	ctx.draw_text(0, 0, '${glyphs.block}${glyphs.slant_right_flat_bottom}')
	ctx.reset_color()
	ctx.push_offset(tea.Offset{ x: 2 })

	ctx.set_color(palette.status_branch_name_bg_color)
	ctx.draw_text(0, 0, '${glyphs.slant_left_flat_top}${glyphs.block}')
	ctx.reset_color()
	ctx.push_offset(tea.Offset{ x: 2 })

	branch_name_label := m.active_branch_name()
	ctx.set_color(palette.matte_white_fg_color)
	ctx.set_bg_color(palette.status_branch_name_bg_color)
	ctx.draw_text(0, 0, branch_name_label)
	ctx.reset_bg_color()
	ctx.reset_color()

	ctx.push_offset(tea.Offset{ x: tea.visible_len(branch_name_label) })

	ctx.set_color(palette.status_branch_name_bg_color)
	ctx.draw_text(-1, 0, '${glyphs.block}${glyphs.slant_right_flat_bottom}')
	ctx.reset_color()

	// status bar spacer left end cap
	ctx.set_color(palette.status_bar_bg_color)
	ctx.draw_text(1, 0, glyphs.slant_left_flat_top)
	ctx.reset_color()
	//

	ctx.clear_offsets_from(blocks_offset)

	cursor_pos_label := m.active_cursor_pos()
	cursor_pos_segment_start := (ctx.window_width() - tea.visible_len(cursor_pos_label)) - 3
	ctx.push_offset(tea.Offset{ x: cursor_pos_segment_start })

	// status bar spacer right end cap
	ctx.set_color(palette.status_bar_bg_color)
	ctx.draw_text(-1, 0, glyphs.slant_right_flat_top)
	ctx.reset_color()
	//

	ctx.set_color(palette.status_cursor_pos_bg_color)
	ctx.draw_text(0, 0, '${glyphs.slant_left_flat_bottom}${glyphs.block}')
	ctx.reset_color()
	ctx.push_offset(tea.Offset{ x: 2 })

	ctx.set_color(palette.bright_off_white_fg_color)
	ctx.set_bg_color(palette.status_cursor_pos_bg_color)
	ctx.draw_text(0, 0, cursor_pos_label)
	ctx.reset_bg_color()
	ctx.reset_color()
	ctx.push_offset(tea.Offset{ x: tea.visible_len(cursor_pos_label) })

	ctx.set_color(palette.status_cursor_pos_bg_color)
	ctx.draw_text(0, 0, glyphs.block)
	ctx.reset_color()
}

fn (m EditorWorkspaceModel) render_leader_or_command_user_input_text(mut ctx tea.Context) {
	match m.mode {
		.leader {
			ctx.set_color(palette.subtle_text_fg_color)
			leader_data := ';' + m.leader_suffix
			ctx.draw_text(ctx.window_width() - tea.visible_len(leader_data) - 1, ctx.window_height() - 1,
				leader_data)
			ctx.reset_color()
		}
		.command {
			ctx.set_color(palette.subtle_text_fg_color)
			command_data := ':' + m.pending_command
			ctx.draw_text(0, ctx.window_height() - 1, command_data)
		}
		else {}
	}
}

fn (m EditorWorkspaceModel) active_file_name() string {
	if d := m.active_editor_data {
		return os.base(d.file_path)
	}
	return '???'
}

fn (m EditorWorkspaceModel) active_branch_name() string {
	if m.branch_name.len > 0 {
		return m.branch_name
	}
	return '???'
}

fn (m EditorWorkspaceModel) active_cursor_pos() string {
	if d := m.active_editor_data {
		return '${d.cursor_row}:${d.cursor_col}'
	}
	return '???'
}

fn (m EditorWorkspaceModel) debug_data() DebugData {
	return DebugData{
		name: 'editor_workspace data'
		data: {
			'initial file path': m.initial_file_path
			'x':                  if e := m.active_editor { e.debug_data() } else { 'null' }
			'xx':                  if d := m.dialog_model { d.debug_data() } else { 'null' }
		}
	}
}

fn (mut m EditorWorkspaceModel) clone() tea.Model {
	return EditorWorkspaceModel{
		...m
	}
}
