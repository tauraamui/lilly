module main

import tauraamui.bobatea as tea

struct EditorWorkspaceModel {
	initial_file_path string
mut:
	in_leader_mode    bool
	active_editor     ?DebuggableModel
}

struct OpenEditorWorkspaceMsg {
	initial_file_path string
}

fn open_editor_workspace(initial_file_path string) tea.Cmd {
	return fn [initial_file_path] () tea.Msg {
		return OpenEditorWorkspaceMsg{ initial_file_path }
	}
}

fn EditorWorkspaceModel.new(initial_file_path string) EditorWorkspaceModel {
	return EditorWorkspaceModel{ initial_file_path: initial_file_path }
}

fn (mut m EditorWorkspaceModel) init() ?tea.Cmd {
	return open_editor(m.initial_file_path)
}

struct ToggleLeaderModeMsg {}

fn toggle_leader_mode() tea.Msg {
	return ToggleLeaderModeMsg{}
}

fn (mut m EditorWorkspaceModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	mut cmds := []tea.Cmd{}

	if !m.in_leader_mode {
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
		tea.KeyMsg {
			match msg.k_type {
				.special {
					match msg.string() {
						'escape' {
							if m.in_leader_mode {
								m.in_leader_mode = false
							}
						}
						else {}
					}
				}
				else {}
			}
		}
		OpenEditorMsg {
			mut e_model := EditorModel.new(msg.file_path)
			cmd := e_model.init()
			m.active_editor = e_model
			u_cmd := cmd or { tea.noop_cmd }
			cmds << u_cmd
		}
		ToggleLeaderModeMsg {
			m.in_leader_mode = true
		}
		else {}
	}

	return m.clone(), tea.batch_array(cmds)
}

fn (m EditorWorkspaceModel) view(mut ctx tea.Context) {
	defer { ctx.reset_bg_color() }

	if mut active_editor := m.active_editor {
		active_editor.view(mut ctx)
	}

	ctx.set_bg_color(tea.Color.ansi(if m.in_leader_mode { 127 } else { 236 }))
	ctx.draw_rect(0, ctx.window_height() - 2, ctx.window_width(), 1)

}

fn (m EditorWorkspaceModel) debug_data() DebugData {
	return DebugData{
		name: 'editor_workspace data'
		data: {
			'initial file path': m.initial_file_path
			'': if e := m.active_editor { e.debug_data() } else { 'null' }
		}
	}
}

fn (mut m EditorWorkspaceModel) clone() tea.Model {
	return EditorWorkspaceModel{
		...m
	}
}

