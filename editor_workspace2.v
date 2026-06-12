module main

import bobatea as tea
import lib.petal
import lib.petal.theme
import lib.boba
import lib.documents
import lib.glyphs
import lib.palette

struct EditorWorkspaceModel2 {
	mode           petal.Mode = .normal
	theme          theme.Theme
	doc_controller &documents.Controller2
mut:
	width          int
	height         int
	dialog_model   ?DebuggableModel
	input_field    boba.InputField

	active_editor  ?DebuggableModel // underlying type of Editor2
}

fn EditorWorkspaceModel2.new(l_theme theme.Theme, doc_controller &documents.Controller2) EditorWorkspaceModel2 {
	return EditorWorkspaceModel2{
		theme: l_theme
		doc_controller: doc_controller
	}
}

fn (mut m EditorWorkspaceModel2) init() fn () tea.Msg {
	m.input_field = boba.InputField.new_with_prefix(':', 0)
	return tea.emit_resize
}

fn (mut m EditorWorkspaceModel2) update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
	match msg {
		tea.KeyMsg {
			return m.key_update(msg)
		}
		tea.ResizedMsg {
			return m.resized_update(msg)
		}
		OpenEditorInWorkspaceMsg {
			return m.open_editor_in_workspace_update(msg)
		}
		SwitchModeMsg {
			return m.switch_mode_update(msg)
		}
		else {}
	}

	return m.forward_msg_to_active_editor(msg)
}

fn (mut m EditorWorkspaceModel2) forward_msg_to_active_editor(msg tea.Msg) (tea.Model, fn () tea.Msg) {
	if mut active_editor := m.active_editor {
		new_active_editor, cmd := active_editor.update(msg)
		if new_active_editor is DebuggableModel {
			m.active_editor = new_active_editor
		}
		return m.clone(), cmd
	}
	return m.clone(), tea.noop_cmd
}

fn (mut m EditorWorkspaceModel2) key_update(msg tea.KeyMsg) (tea.Model, fn () tea.Msg) {
	if m.mode == .normal && msg.k_type == .runes && msg.string() == 'q' {
		return m.clone(), tea.quit
	}

	return m.forward_msg_to_active_editor(EditorModelKeyMsg{
		key_msg: msg
		mode: m.mode
	})
}

fn (mut m EditorWorkspaceModel2) resized_update(msg tea.ResizedMsg) (tea.Model, fn () tea.Msg) {
	m.width = msg.window_width
	m.height = msg.window_height

	return m.forward_msg_to_active_editor(EditorModelMsg{
		id: 0,
		mode: m.mode,
		msg: tea.ResizedMsg{
			window_width: msg.window_width
			window_height: msg.window_height - 2
		},
	})
}

fn (mut m EditorWorkspaceModel2) open_editor_in_workspace_update(msg OpenEditorInWorkspaceMsg) (tea.Model, fn () tea.Msg) {
	doc_id := m.doc_controller.open_document(msg.file_path) or {
		return m.clone(), debug_log('failed to open document ${msg.file_path}: ${err}')
	}
	mut e_model := EditorModel2.new(m.theme, 0, doc_id, msg.file_path, m.doc_controller)
	model_init_cmd := e_model.init()
	m.active_editor = e_model
	return m.clone(), tea.sequence(model_init_cmd)
}

fn (mut m EditorWorkspaceModel2) switch_mode_update(msg SwitchModeMsg) (tea.Model, fn () tea.Msg) {
	_, cmd := m.forward_msg_to_active_editor(EditorModelMsg{
		id: 0 // will be active editors when forwarding to all editor instances
		mode: m.mode
		msg: msg
	})
	return m.clone_with_mode(msg.mode), cmd
}

fn (m EditorWorkspaceModel2) view(mut ctx tea.Context) {
	if mut editor := m.active_editor {
		editor.view(mut ctx)
	}

	m.render_status_bar(mut ctx)
}

fn (m EditorWorkspaceModel2) render_status_bar(mut ctx tea.Context) {
	ctx.set_bg_color(m.theme.status_bar_spacer)
	ctx.draw_rect(0, ctx.window_height() - 2, ctx.window_width(), 1)
	ctx.reset_bg_color()

	m.render_status_blocks(mut ctx)
	// m.render_leader_or_command_user_input_text(mut ctx)
}

fn (m EditorWorkspaceModel2) render_status_blocks(mut ctx tea.Context) {
	status_bar_offset := ctx.push_offset(tea.Offset{ y: ctx.window_height() - 2 })
	defer { ctx.clear_offsets_from(status_bar_offset) }

	mode_color := m.mode.color(m.theme)
	ctx.set_color(mode_color)
	ctx.draw_text(0, 0, '${glyphs.left_rounded}${glyphs.block}')
	ctx.reset_color()
	blocks_offset := ctx.push_offset(tea.Offset{ x: 2 })

	mode_label := m.mode.str()
	ctx.set_color(palette.matte_black_fg_color)
	ctx.set_bg_color(mode_color)
	ctx.draw_text(0, 0, mode_label)
	ctx.reset_bg_color()
	ctx.reset_color()

	ctx.push_offset(tea.Offset{ x: tea.visible_len(mode_label) })

	ctx.set_color(mode_color)
	ctx.draw_text(0, 0, '${glyphs.block}${glyphs.slant_right_flat_bottom}')
	ctx.reset_color()
	ctx.push_offset(tea.Offset{ x: 2 })

	file_name_bg_color := m.theme.status_file_name
	ctx.set_color(file_name_bg_color)
	ctx.draw_text(0, 0, '${glyphs.slant_left_flat_top}${glyphs.block}')
	ctx.reset_color()
	ctx.push_offset(tea.Offset{ x: 2 })

	file_name_label := m.active_file_name()
	ctx.set_color(palette.fg_color(file_name_bg_color))
	ctx.set_bg_color(file_name_bg_color)
	ctx.draw_text(0, 0, file_name_label)
	ctx.reset_bg_color()
	ctx.reset_color()

	ctx.push_offset(tea.Offset{ x: tea.visible_len(file_name_label) })

	ctx.set_color(file_name_bg_color)
	ctx.draw_text(0, 0, '${glyphs.block}${glyphs.slant_right_flat_bottom}')
	ctx.reset_color()
	ctx.push_offset(tea.Offset{ x: 2 })

	branch_name_bg_color := m.theme.status_branch_name
	ctx.set_color(branch_name_bg_color)
	ctx.draw_text(0, 0, '${glyphs.slant_left_flat_top}${glyphs.block}')
	ctx.reset_color()
	ctx.push_offset(tea.Offset{ x: 2 })

	branch_name_label := m.active_branch_name()
	ctx.set_color(palette.fg_color(branch_name_bg_color))
	ctx.set_bg_color(branch_name_bg_color)
	ctx.draw_text(0, 0, branch_name_label)
	ctx.reset_bg_color()
	ctx.reset_color()

	ctx.push_offset(tea.Offset{ x: tea.visible_len(branch_name_label) })

	ctx.set_color(branch_name_bg_color)
	ctx.draw_text(0, 0, '${glyphs.block}${glyphs.slant_right_flat_bottom}')
	ctx.reset_color()

	// status bar spacer left end cap
	ctx.set_color(m.theme.status_bar_spacer)
	ctx.draw_text(2, 0, glyphs.slant_left_flat_top)
	ctx.reset_color()
	//

	ctx.clear_offsets_from(blocks_offset)

	cursor_pos_label := m.active_cursor_pos()
	cursor_pos_segment_start := (ctx.window_width() - tea.visible_len(cursor_pos_label)) - 3
	ctx.push_offset(tea.Offset{ x: cursor_pos_segment_start })

	// status bar spacer right end cap
	ctx.set_color(m.theme.status_bar_spacer)
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

fn (m EditorWorkspaceModel2) active_file_name() string {
	/*
	if d := m.active_editor_data {
		return os.base(d.file_path)
	}
	*/
	return '???'
}

fn (m EditorWorkspaceModel2) active_branch_name() string {
	/*
	if m.branch_name.len > 0 {
		return m.branch_name
	}
	*/
	return '???'
}

fn (m EditorWorkspaceModel2) active_cursor_pos() string {
	/*
	if d := m.active_editor_data {
		return '${d.cursor_row}:${d.cursor_col}'
	}
	*/
	return '???'
}

fn (m EditorWorkspaceModel2) width() int {
	return m.width
}

fn (m EditorWorkspaceModel2) height() int {
	return m.height
}

fn (m EditorWorkspaceModel2) debug_data() DebugData {
	return DebugData{
		name: 'editor workspace'
	}
}

fn (m EditorWorkspaceModel2) clone() tea.Model {
	return EditorWorkspaceModel2{
		...m
	}
}

fn (m EditorWorkspaceModel2) clone_with_mode(mode petal.Mode) tea.Model {
	return EditorWorkspaceModel2{
		...m
		mode: mode
	}
}

struct OpenEditorInWorkspaceMsg {
	file_path string
}

fn open_editor_in_workspace_cmd(file_path string) fn () tea.Msg {
	return fn [file_path] () tea.Msg {
		return OpenEditorInWorkspaceMsg{
			file_path: file_path
		}
	}
}


