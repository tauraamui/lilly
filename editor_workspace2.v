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
import time
import bobatea as tea
import lib.petal
import lib.petal.theme
import lib.boba
import lib.documents
import lib.glyphs
import lib.palette
import lib.cfg
import lib.nanoid

struct EditorWorkspaceModel2 {
	mode           petal.Mode = .normal
	doc_controller &documents.Controller2
	config         EditorWorkspaceConfig
mut:
	width         int
	height        int
	dialog_model  ?DebuggableModel
	input_field   boba.InputField
	message_label ?MessageLabel
	branch_name   ?string
	leader_suffix []rune

	active_modal       ?DebuggableModel
	// active_modal_data  ?ModalData // TODO(tauraamui) [2026-06-17]: wire this up to query and response messages
	active_editor_data ?EditorData2
	active_editor_id   nanoid.ID
	editors            map[nanoid.ID]DebuggableModel
	tree               boba.Tree[nanoid.ID]
}

struct EditorWorkspaceConfig {
	theme                 theme.Theme
	leader_key            string
	tab_width             int
	relative_line_numbers bool
}

fn EditorWorkspaceConfig.new(base_cfg cfg.Config) EditorWorkspaceConfig {
	return EditorWorkspaceConfig{
		theme:       base_cfg.theme
		leader_key:  base_cfg.leader_key
		tab_width:   base_cfg.tab_width
		relative_line_numbers: base_cfg.relative_line_numbers
	}
}

fn EditorWorkspaceModel2.new(config EditorWorkspaceConfig, doc_controller &documents.Controller2) EditorWorkspaceModel2 {
	return EditorWorkspaceModel2{
		config:         config
		doc_controller: doc_controller
		tree:           boba.Tree[nanoid.ID]{}
	}
}

fn (mut m EditorWorkspaceModel2) init() fn () tea.Msg {
	m.input_field = boba.InputField.new_with_prefix(':', 0)
	// the tree is planted when the first editor opens (open_editor_in_workspace_update),
	// using that editor's generated id; until then it holds no editor leaves.
	return tea.sequence(tea.emit_resize, query_git_branch)
}

fn (mut m EditorWorkspaceModel2) update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
	match msg {
		tea.FocusedMsg {
			return m.clone(), query_git_branch
		}
		tea.KeyMsg {
			return m.key_update(msg)
		}
		tea.ResizedMsg {
			return m.resized_update(msg)
		}
		OpenEditorInWorkspaceMsg {
			return m.open_editor_in_workspace_update(msg)
		}
		OpenEditorInSplitMsg {
			return m.open_editor_in_split_update(msg)
		}
		OpenDialogMsg {
			mut d_modal := msg.model
			init_cmd := d_modal.init()
			m.dialog_model = d_modal
			return m.clone(), init_cmd
		}
		CloseDialogMsg {
			m.dialog_model = ?DebuggableModel(none)
			return m.clone(), tea.noop_cmd
		}
		SwitchModeMsg {
			return m.switch_mode_update(msg)
		}
		DisplayMessageMsg {
			m.message_label = MessageLabel{
				contents: msg.contents
				ccolor:   msg.m_type.color(m.config.theme)
			}
		}
		HideMessageMsg {
			m.message_label = ?MessageLabel(none)
		}
		EditorData2ResultMsg { // TODO(tauraamui) rename query message result type to make it clear its a query result
			m.active_editor_data = msg.data
			return m.clone(), tea.noop_cmd
		}
		GitBranchQueryResultMsg {
			m.branch_name = msg.branch_name
			return m.clone(), tea.noop_cmd
		}
		boba.CursorBlinkMsg {
			match m.mode {
				.command {
					i_input, i_cmd := m.input_field.update(msg)
					m.input_field = i_input
					return m.clone(), i_cmd
				}
				else {}
			}
		}
		else {}
	}

	return m.forward_msg_to_all_editors(msg)
}

fn (mut m EditorWorkspaceModel2) forward_msg_to_all_editors(msg tea.Msg) (tea.Model, fn () tea.Msg) {
	mut cmds := []tea.Cmd{}
	for id, mut editor in m.editors {
		new_editor, cmd := editor.update(msg)
		if new_editor is DebuggableModel {
			m.editors[id] = new_editor
			cmds << cmd
		}
	}
	return m.clone(), tea.batch_array(cmds)
}

fn (mut m EditorWorkspaceModel2) key_update(msg tea.KeyMsg) (tea.Model, fn () tea.Msg) {
	match m.mode {
		.normal {
			model, cmd := m.normal_mode_key_update(msg)
			if cmd != tea.noop_cmd {
				return model, cmd // do not forward key event to editor in normal mode if consumed here
			}
		}
		.command {
			return m.command_mode_key_update(msg) // never forward key events to editor when in command mode
		}
		.leader {
			return m.leader_mode_key_update(msg)
		}
		else {}
	}

	m_clone, cmd := m.forward_msg_to_all_editors(EditorModelKeyMsg{
		active_id: m.active_editor_id
		key_msg: msg
		mode:    m.mode
	})
	return m_clone, tea.sequence(cmd, query_editor_data2(m.active_editor_id))
}

fn (mut m EditorWorkspaceModel2) normal_mode_key_update(msg tea.KeyMsg) (tea.Model, fn () tea.Msg) {
	if mut d_modal := m.dialog_model {
		d_model, dialog_cmd := d_modal.update(msg)
		if d_model is DebuggableModel {
			m.dialog_model = d_model
		}
		return m.clone(), dialog_cmd
	}

	match msg.k_type {
		.special {
			match msg.string() {
				'escape' {
					return m.clone(), hide_message
				}
				else {}
			}
		}
		.runes {
			match msg.string() {
				':' {
					i_input, i_cmd := m.input_field.update(tea.FocusedMsg{})
					m.input_field = i_input
					return m.clone(), tea.sequence(hide_message, switch_mode(.command), i_cmd)
				}
				m.config.leader_key {
					return m.clone(), switch_mode(.leader)
				}
				else {}
			}
		}
	}

	return m.clone(), tea.noop_cmd
}

fn (mut m EditorWorkspaceModel2) command_mode_key_update(msg tea.KeyMsg) (tea.Model, fn () tea.Msg) {
	match msg.k_type {
		.special {
			cmd := match msg.string() {
				'escape' {
					tea.noop_cmd
				}
				'enter' {
					execute_command(m.active_editor_id, m.input_field.value())
				}
				'backspace' {
					return m.clone(), tea.noop_cmd
				}
				else {
					tea.noop_cmd
				}
			}

			i_input, i_cmd := m.input_field.update(tea.BlurredMsg{})
			m.input_field = i_input
			return m.clone(), tea.sequence(switch_mode(.normal), i_cmd, cmd)
		}
		.runes {
			i_field, i_cmd := m.input_field.update(msg)
			m.input_field = i_field
			return m.clone(), i_cmd
		}
	}

	return m.clone(), tea.noop_cmd
}

fn (mut m EditorWorkspaceModel2) leader_mode_key_update(msg tea.KeyMsg) (tea.Model, fn () tea.Msg) {
	match msg.k_type {
		.special {
			match msg.string() {
				'escape' {
					return m.clone(), switch_mode(.normal)
				}
				else {}
			}
		}
		.runes {
			m.leader_suffix << msg.string().runes()
			match m.leader_suffix.string() {
				'ff' {
					return m.clone(), tea.sequence(switch_mode(.normal), open_file_picker(m.config.theme))
				}
				else {}
			}
		}
	}
	return m.clone(), tea.noop_cmd
}

fn (mut m EditorWorkspaceModel2) resized_update(msg tea.ResizedMsg) (tea.Model, fn () tea.Msg) {
	m.width = msg.window_width
	m.height = msg.window_height

	i_field, i_cmd := m.input_field.update(msg)
	m.input_field = i_field

	mut cmds := []tea.Cmd{}
	for id, layout in m.tree.layouts(m.width, m.height - 2) {
		if mut editor := m.editors[id] {
			// mirror the divider insets applied in view(): a leaf with a
			// neighbour above/left loses one cell to that divider, so the
			// editor's usable viewport is that much smaller.
			left_inset := if layout.x > 0 { 1 } else { 0 }
			top_inset := if layout.y > 0 { 1 } else { 0 }
			new_editor, cmd := editor.update(EditorModel2Msg{
				active_id: m.active_editor_id
				mode: m.mode
				msg: tea.ResizedMsg{
					window_width: layout.width - left_inset
					window_height: layout.height - top_inset
				}
			})
			if new_editor is DebuggableModel {
				m.editors[id] = new_editor
				cmds << cmd
			}
		}
	}

	mut d_cmd := tea.noop_cmd
	if mut d_modal := m.dialog_model {
		d_model, dialog_cmd := d_modal.update(tea.ResizedMsg{
			window_width: int(f64(msg.window_width) * .8)
			window_height: int(f64(msg.window_height) * .8)
		})
		if d_model is DebuggableModel {
			m.dialog_model = d_model
		}
		d_cmd = dialog_cmd
	}

	return m.clone(), tea.sequence(i_cmd, tea.batch_array(cmds), d_cmd)
}

// TODO(tauraamui): merge these two methods since in the end they should really be doing the same thing
fn (mut m EditorWorkspaceModel2) open_editor_in_workspace_update(msg OpenEditorInWorkspaceMsg) (tea.Model, fn () tea.Msg) {
	doc_id := m.doc_controller.open_document(msg.file_path) or {
		return m.clone(), debug_log('failed to open document ${msg.file_path}: ${err}')
	}
	editor_id := nanoid.simple()
	mut e_model := EditorModel2.new(m.config, editor_id, doc_id, msg.file_path, m.doc_controller)
	model_init_cmd := e_model.init()
	m.active_editor_id = editor_id
	m.editors[editor_id] = e_model
	m.tree.plant(editor_id)
	return m.clone(), tea.sequence(model_init_cmd, focus_editor2(m.active_editor_id), tea.emit_resize)
}

fn (mut m EditorWorkspaceModel2) open_editor_in_split_update(msg OpenEditorInSplitMsg) (tea.Model, fn () tea.Msg) {
	if active_editor := m.editors[msg.active_editor_id] {
		if active_editor is EditorModel2 {
			new_editor_id := nanoid.simple()
			if !m.tree.split(msg.active_editor_id, new_editor_id, msg.direction) { return m.clone(), tea.noop_cmd }
			mut e_model := EditorModel2.new(m.config, new_editor_id, active_editor.doc_id, active_editor.file_path, m.doc_controller)
			model_init_cmd := e_model.init()
			m.active_editor_id = new_editor_id
			m.editors[new_editor_id] = e_model
			return m.clone(), tea.sequence(model_init_cmd, focus_editor2(m.active_editor_id), tea.emit_resize)
		}
	}
	return m.clone(), tea.noop_cmd
}

fn (mut m EditorWorkspaceModel2) switch_mode_update(msg SwitchModeMsg) (tea.Model, fn () tea.Msg) {
	if m.mode == .leader {
		m.leader_suffix = []
	}
	_, cmd := m.forward_msg_to_all_editors(EditorModel2Msg{
		active_id:   m.active_editor_id // will be active editors when forwarding to all editor instances
		mode: m.mode
		msg:  SwitchModeMsg{
			from: m.mode // send current mode pre-change as mode moving from
			mode: msg.mode
		}
	})
	return m.clone_with_mode(msg.mode), cmd
}

fn (mut m EditorWorkspaceModel2) view(mut ctx tea.Context) {
	layouts := m.tree.layouts(m.width, m.height - 2)
	for id, layout in layouts {
		mut editor := m.editors[id] or { continue }
		// a leaf owns the divider on any side where it has a neighbour: a left
		// divider when it isn't flush to the left edge, a top divider when it
		// isn't flush to the top. The divider eats one cell of the leaf, so the
		// editor content is inset by the same amount (see resized_update, which
		// must shrink the editor by these insets or it renders a row/col too many).
		left_inset := if layout.x > 0 { 1 } else { 0 }
		top_inset := if layout.y > 0 { 1 } else { 0 }
		ctx.push_offset(tea.Offset{ x: layout.x, y: layout.y })
		ctx.set_clip_area(tea.ClipArea{ 0, 0, layout.width, layout.height })
		ctx.push_offset(tea.Offset{ x: left_inset, y: top_inset })
		editor.view(mut ctx)
		ctx.pop_offset()
		ctx.clear_clip_area()
		ctx.pop_offset()
	}

	m.render_dividers(mut ctx, layouts)

	m.render_status_bar(mut ctx)

	if mut open_modal := m.dialog_model {
		id := ctx.push_offset(tea.Offset{
			x: int(f64(m.width / 2)) - int(f64(open_modal.width() / 2))
			y: int(f64(m.height / 2)) - int(f64(open_modal.height() / 2))
		})
		defer { ctx.clear_offsets_from(id) }

		open_modal.view(mut ctx)
	}
}

// render_dividers paints the lines between panes. The tree resolves each cell's
// connecting arms (so junctions render as proper tees), and a cell is drawn in
// the active colour when it lies on the active editor's own top/left frame.
fn (m EditorWorkspaceModel2) render_dividers(mut ctx tea.Context, layouts map[nanoid.ID]boba.Layout) {
	active := layouts[m.active_editor_id]
	m.tree.each_divider(m.width, m.height - 2, fn [mut ctx, active] (x int, y int, up bool, down bool, left bool, right bool) {
		on_active := (active.x > 0 && x == active.x && y >= active.y && y < active.y + active.height)
			|| (active.y > 0 && y == active.y && x >= active.x && x < active.x + active.width)
		ctx.set_color(if on_active { active_editor_border_color } else { inactive_editor_border_color })
		ctx.draw_text(x, y, glyphs.box_junction(up, down, left, right))
	})
	ctx.reset_color()
}

fn (m EditorWorkspaceModel2) render_status_bar(mut ctx tea.Context) {
	ctx.set_bg_color(m.config.theme.status_bar_spacer)
	ctx.draw_rect(0, ctx.window_height() - 2, ctx.window_width(), 1)
	ctx.reset_bg_color()

	m.render_status_blocks(mut ctx)
	m.render_leader_or_command_user_input_text(mut ctx)
}

fn (m EditorWorkspaceModel2) render_status_blocks(mut ctx tea.Context) {
	status_bar_offset := ctx.push_offset(tea.Offset{ y: ctx.window_height() - 2 })
	defer { ctx.clear_offsets_from(status_bar_offset) }

	mode_color := m.mode.color(m.config.theme)
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

	file_name_bg_color := m.config.theme.status_file_name
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

	branch_name_bg_color := m.config.theme.status_branch_name
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
	ctx.set_color(m.config.theme.status_bar_spacer)
	ctx.draw_text(2, 0, glyphs.slant_left_flat_top)
	ctx.reset_color()
	//

	ctx.clear_offsets_from(blocks_offset)

	cursor_pos_label := m.active_cursor_pos()
	cursor_pos_segment_start := (ctx.window_width() - tea.visible_len(cursor_pos_label)) - 3
	ctx.push_offset(tea.Offset{ x: cursor_pos_segment_start })

	// status bar spacer right end cap
	ctx.set_color(m.config.theme.status_bar_spacer)
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

fn (m EditorWorkspaceModel2) render_leader_or_command_user_input_text(mut ctx tea.Context) {
	if msg_label := m.message_label {
		ctx.set_color(msg_label.ccolor)
		ctx.draw_text(1, ctx.window_height() - 1, msg_label.contents)
		ctx.reset_color()
		return
	}
	match m.mode {
		.leader {
			ctx.set_color(palette.subtle_text_fg_color)
			leader_data := '${m.config.leader_key}${m.leader_suffix.string()}'
			ctx.draw_text(ctx.window_width() - tea.visible_len(leader_data) - 1,
				ctx.window_height() - 1, leader_data)
			ctx.reset_color()
		}
		.command {
			ctx.set_color(palette.subtle_text_fg_color)
			ctx.push_offset(tea.Offset{ y: ctx.window_height() - 1 })
			m.input_field.view(mut ctx)
			ctx.pop_offset()
		}
		.normal {
			/*
			if d := m.active_editor_data {
				if d.chord_display.len > 0 {
					ctx.set_color(palette.subtle_text_fg_color)
					ctx.draw_text(ctx.window_width() - tea.visible_len(d.chord_display) - 1,
						ctx.window_height() - 1, d.chord_display)
					ctx.reset_color()
				}
			}
			*/
		}
		else {}
	}
}

fn (m EditorWorkspaceModel2) active_file_name() string {
	if d := m.active_editor_data {
		return os.base(d.file_path)
	}
	return '???'
}

fn (m EditorWorkspaceModel2) active_branch_name() string {
	return m.branch_name or { '???' }
}

fn (m EditorWorkspaceModel2) active_cursor_pos() string {
	if d := m.active_editor_data {
		return '${d.cursor_row}:${d.cursor_col}'
	}
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

struct OpenEditorInSplitMsg {
	active_editor_id nanoid.ID
	direction        boba.SplitDirection
}

fn open_editor_in_split_cmd(editor_id nanoid.ID, direction boba.SplitDirection) fn () tea.Msg {
	return fn [editor_id, direction] () tea.Msg {
		return OpenEditorInSplitMsg{
			active_editor_id: editor_id
			direction: direction
		}
	}
}

fn focus_editor2(editor_id nanoid.ID) fn () tea.Msg {
	return fn [editor_id] () tea.Msg {
		return EditorModel2Msg{
			active_id: editor_id
			msg: tea.FocusedMsg{}
		}
	}
}

struct MessageLabel {
	contents string
	ccolor   tea.Color
}

enum DisplayMessageType {
	normal
	warning
	error
}

fn (t DisplayMessageType) color(ttheme theme.Theme) tea.Color {
	return match t {
		.normal { ttheme.petal_green }
		.warning { ttheme.status_orange }
		.error { ttheme.petal_red }
	}
}

struct DisplayMessageMsg {
	contents string
	m_type   DisplayMessageType
}

fn display_message(m_type DisplayMessageType, contents string) tea.Cmd {
	return fn [m_type, contents] () tea.Msg {
		return DisplayMessageMsg{
			contents: contents
			m_type:   m_type
		}
	}
}

fn emit_focused() tea.Msg {
	return tea.FocusedMsg{}
}

fn display_error_message(contents string) tea.Cmd {
	return tea.sequence(display_message(.error, contents), hide_message_after(6 * time.second))
}

struct HideMessageMsg {
	time time.Time
}

fn hide_message() tea.Msg {
	return HideMessageMsg{}
}

fn hide_message_after(duration time.Duration) tea.Cmd {
	return tea.tick(duration, fn (t time.Time) tea.Msg {
		return HideMessageMsg{
			time: t
		}
	})
}

fn execute_command(active_editor_id nanoid.ID, cmd string) tea.Cmd {
	match cmd {
		'qa' {
			return tea.quit
		}
		'w' {
			return write_to_disk2(active_editor_id)
		}
		'vs' {
			return open_editor_in_split_cmd(active_editor_id, .horizontal)
		}
		'sp' {
			return open_editor_in_split_cmd(active_editor_id, .vertical)
		}
		else {
			return display_error_message('unrecognised command: ${cmd}')
		}
	}

	return tea.noop_cmd
}

struct QueryGitBranchMsg {}

fn query_git_branch() tea.Msg {
	return QueryGitBranchMsg{}
}

struct GitBranchQueryResultMsg {
	branch_name string
}

fn git_branch_query_result(branch_name string) tea.Cmd {
	return fn [branch_name] () tea.Msg {
		return GitBranchQueryResultMsg{
			branch_name: branch_name
		}
	}
}


