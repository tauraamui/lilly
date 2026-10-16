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

import time
import bobatea as tea
import lib.petal
import lib.documents
import lib.documents.cursor
import lib.syntax
import lib.palette
import lib.nanoid

struct EditorModel2 {
	config         EditorWorkspaceConfig
	id             nanoid.ID
	file_path      string
	doc_id         nanoid.ID
	doc_controller &documents.Controller2
mut:
	in_focus              bool
	chord                 Chord
	viewport_width        int
	viewport_height       int
	top_line              int
	visual_sel_start_col  ?u64
	visual_sel_start_line ?u64
	visual_linewise       bool
	lang_syn              syntax.Syntax = syntax.noop_syntax
	token_parser          syntax.Parser
	// scope_colours is the theme colour of each syntax scope, built on first
	// render
	scope_colours []ScopeColour
	// parser_line_states holds the lexer state at the start of lines 0 to
	// len-1. Drawing extends it, through ensure_parser_states, only down to
	// the top of the view, so opening a file lexes the lines above the view
	// and no more before the first frame. Background lexing extends it the
	// rest of the way, and an edit that changes how the lines below it lex
	// trims it a little past the view for background lexing to redo.
	parser_line_states []syntax.State
	// parser_gen is the document edit generation parser_line_states is up to
	// date with. 0 means never synced, which forces a full rebuild.
	parser_gen u64
	// syntax_tree is the document's context tree, kept up to date with edits
	// alongside parser_line_states and queried through syntax_ancestors and
	// syntax_find
	syntax_tree syntax.Tree
	// closed_folds are the folds closed in this editor, by start line,
	// outermost first. One inside another closed one stays closed when that
	// one opens, as in Vim.
	closed_folds []Fold
	// outer_folds are the closed folds no other closed fold is around: the
	// ones that hide lines
	outer_folds []Fold
	// fold_gen is the document edit generation closed_folds are up to date
	// with
	fold_gen u64
	// fold_return is where the cursor was before a fold closed around it
	fold_return ?FoldReturn
	// folds_all is set by zM, until zR: every fold is closed, but only as its
	// lines come into reach, which fold_reach records, so zM costs the lines
	// around the view rather than the whole document (see reach_folds)
	folds_all  bool
	fold_reach []LineRange
	// insert_line_pristine_indent mirrors Neovim's 'autoindent' semantics: true
	// only while the current line's sole content is whitespace that *this*
	// insert session auto-inserted (via `o`/`O`) and the user hasn't typed
	// anything but backspace since. Any real keystroke clears it, so
	// user-typed whitespace is left alone on leaving insert mode.
	insert_line_pristine_indent bool
	// mode is the mode the editor was last switched to
	mode petal.Mode
	// change_open is set by a change such as `ci{`, whose deletion and the
	// insert that follows are undone as one, so the undo group it began is
	// left open on going into insert mode
	change_open bool
}

fn EditorModel2.new(config EditorWorkspaceConfig, id nanoid.ID, doc_id nanoid.ID, file_path string, doc_controller &documents.Controller2) EditorModel2 {
	return EditorModel2{
		config:         config
		id:             id
		file_path:      file_path
		doc_id:         doc_id
		doc_controller: doc_controller
		token_parser:   syntax.Parser{}
	}
}

fn (mut m EditorModel2) init() tea.Cmd {
	return tea.batch(tea.emit_resize(), load_syntax2(m.id, m.file_path), query_editor_data2(m.id))
}

fn (mut m EditorModel2) update(msg tea.Msg) (tea.Model, tea.Cmd) {
	match msg {
		EditorModelKeyMsg {
			if m.id != msg.active_id { return m.clone(), tea.no_cmd }
			match msg.mode {
				.normal {
					return m.normal_mode_update(msg.key_msg)
				}
				.insert {
					return m.insert_mode_update(msg.key_msg)
				}
				.visual {
					return m.visual_mode_update(msg.key_msg)
				}
				.visual_line {
					return m.visual_mode_update(msg.key_msg)
				}
				else {}
			}
		}
		EditorModel2Msg {
			return m.editor_model_update(msg.active_id, msg.msg)
		}
		else {}
	}

	return m.clone(), tea.no_cmd
}

fn (mut m EditorModel2) editor_model_update(editor_id nanoid.ID, msg tea.Msg) (tea.Model, tea.Cmd) {
	match msg {
		tea.FocusedMsg {
			m.in_focus = editor_id == m.id
		}
		tea.ResizedMsg {
			m.viewport_width = msg.window_width // artificially shrunk by parent model EditorWorkspace
			m.viewport_height = msg.window_height
		}
		SwitchModeMsg {
			return m.switch_mode_update(msg)
		}
		QueryEditorData2Msg {
			if editor_id != m.id { return m.clone(), tea.no_cmd }
			return m.clone(), editor_data2(m.data())
		}
		SyntaxLoadedMsg {
			if editor_id != m.id { return m.clone(), tea.no_cmd }
			m.lang_syn = msg.syn
			m.token_parser.set_syntax(m.lang_syn)
			m.invalidate_parser_cache()
			if msg.err_msg.len > 0 {
				return m.clone(), debug_log(msg.err_msg)
			}
		}
		WriteToDiskMsg {
			if editor_id != m.id { return m.clone(), tea.no_cmd }
			m.doc_controller.write_to_disk(m.doc_id, m.file_path) or {
				return m.clone(), raise_error('failed to write to disk: ${err}')
			}
			success_msg := 'written ${m.file_path} successfully'
			return m.clone(), tea.sequence(debug_log(success_msg), display_message(.normal,
				success_msg), hide_message_after(6 * time.second))
		}
		else {}
	}

	if editor_id == m.id {
		m.scroll_to_cursor()
	}
	return m.clone(), tea.no_cmd
}

fn (mut m EditorModel2) switch_mode_update(msg SwitchModeMsg) (tea.Model, tea.Cmd) {
	// a chord left half typed doesn't carry over into the new mode, where its
	// next key would finish it
	m.chord.reset()
	m.visual_sel_start_line = ?u64(none)
	m.visual_sel_start_col = ?u64(none)
	m.visual_linewise = false
	m.mode = msg.mode

	match msg.mode {
		.normal {
			if m.in_focus {
				m.switch_to_normal_mode_update(msg)
				m.insert_line_pristine_indent = false
				// an insert is undone in one go with the indent leaving it
				// takes out
				m.doc_controller.commit_undo_group(m.doc_id)
			}
		}
		.visual {
			cursor_line, cursor_col := m.doc_controller.cursor_line_and_x(m.doc_id)
			m.visual_sel_start_line = cursor_line
			m.visual_sel_start_col = cursor_col
		}
		.visual_line {
			cursor_line, cursor_col := m.doc_controller.cursor_line_and_x(m.doc_id)
			m.visual_sel_start_line = cursor_line
			m.visual_sel_start_col = cursor_col
			m.visual_linewise = true
		}
		.insert {
			if m.in_focus {
				if !m.change_open {
					m.doc_controller.commit_undo_group(m.doc_id)
				}
				m.doc_controller.begin_undo_group(m.doc_id)
			}
			m.change_open = false
		}
		else {}
	}

	return m.clone(), tea.no_cmd
}

fn (mut m EditorModel2) switch_to_normal_mode_update(msg SwitchModeMsg) {
	match msg.from {
		.normal {
			m.doc_controller.move_cursor_left(m.doc_id)
			return
		}
		.insert {
			if m.insert_line_pristine_indent {
				cursor_line, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
				line_bytes := m.doc_controller.get_line_bytes(m.doc_id, cursor_line) or { []u8{} }
				if line_bytes.len > 0 && line_bytes.bytestr().trim_space().len == 0 {
					m.doc_controller.delete_range(m.doc_id, cursor.Range{
						start: cursor.Pos.new(0, int(cursor_line))
						end:   cursor.Pos.new(line_bytes.len, int(cursor_line))
					})
					return
				}
			}
			m.doc_controller.move_cursor_left(m.doc_id)
		}
		else {}
	}
}

fn (mut m EditorModel2) normal_mode_update(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	mut cmds := []tea.Cmd{}
	match msg.k_type {
		.runes {
			// with an operator pending, `i` starts a text object, as in `di(`
			key := if m.chord.pending_operator() { '' } else { msg.string() }
			match key {
				'i' {
					m.insert_line_pristine_indent = false
					cmds << switch_mode(.insert)
				}
				'v' {
					cmds << switch_mode(.visual)
				}
				'V' {
					cmds << switch_mode(.visual_line)
				}
				else {
					if action := m.chord.feed(msg.string()) {
						cmd, switching_mode := m.execute_action_normal(action)
						if !switching_mode {
							m.clamp_cursor_to_line_end()
						}
						m.scroll_to_cursor()
						cmds << cmd
					}
				}
			}
		}
		.special {
			match msg.string() {
				'delete' {
					// undone on its own, as x is
					m.doc_controller.begin_undo_group(m.doc_id)
					m.doc_controller.delete_char_at(m.doc_id)
					m.doc_controller.commit_undo_group(m.doc_id)
				}
				'left' {
					m.doc_controller.move_cursor_left(m.doc_id)
				}
				'down' {
					m.move_cursor_rows(1)
				}
				'right' {
					m.doc_controller.move_cursor_right(m.doc_id)
				}
				'up' {
					m.move_cursor_rows(-1)
				}
				'ctrl+r' {
					m.doc_controller.redo(m.doc_id)
				}
				'ctrl+u' {
					m.scroll_page_up()
				}
				'ctrl+d' {
					m.scroll_page_down()
				}
				else {}
			}
		}
	}

	m.clamp_cursor_to_line_end()
	m.scroll_to_cursor()
	return m.clone(), tea.batch_array(cmds)
}

fn (mut m EditorModel2) insert_mode_update(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	mut cmds := []tea.Cmd{}
	match msg.k_type {
		.runes {
			m.insert_line_pristine_indent = false
			for cr in msg.string().runes_iterator() {
				m.doc_controller.insert_rune(m.doc_id, cr)
				if cr in [`)`, `]`, `}`] {
					m.align_closer()
				}
			}
		}
		.special {
			match msg.string() {
				'escape' {
					cmds << switch_mode(.normal)
				}
				'enter' {
					m.open_line()
				}
				'ctrl+i' { // TAB
					m.insert_line_pristine_indent = false

					if m.config.convert_tabs_to_spaces {
						m.doc_controller.insert_string(m.doc_id, ' '.repeat(m.config.tab_width))
					} else {
						m.doc_controller.insert(m.doc_id, `\t`)
					}
				}
				'backspace' {
					// backspace is exempt (mirrors Neovim's <BS>/CTRL-D exemption):
					// trimming auto-inserted indent back down doesn't disqualify
					// the line from being cleared on leaving insert mode.
					m.doc_controller.backspace(m.doc_id)
				}
				'delete' {
					m.insert_line_pristine_indent = false
					m.doc_controller.delete(m.doc_id)
				}
				'left' {
					m.doc_controller.move_cursor_left(m.doc_id)
				}
				'down' {
					m.move_cursor_rows(1)
				}
				'right' {
					m.doc_controller.move_cursor_right(m.doc_id)
				}
				'up' {
					m.move_cursor_rows(-1)
				}
				else {}
			}
		}
	}

	m.scroll_to_cursor()
	return m.clone(), tea.batch_array(cmds)
}

fn (mut m EditorModel2) visual_mode_update(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	mut cmds := []tea.Cmd{}
	match msg.k_type {
		.runes {
			if action := m.chord.feed_visual(msg.string()) {
				cmd, switching_mode := m.execute_action_visual(action)
				if !switching_mode {
					m.clamp_cursor_to_line_end()
				}
				m.scroll_to_cursor()
				cmds << cmd
			}
		}
		.special {
			match msg.string() {
				'escape' {
					cmds << switch_mode(.normal)
				}
				else {}
			}
		}
	}

	m.clamp_cursor_to_line_end()
	m.scroll_to_cursor()
	return m.clone(), tea.batch_array(cmds)
}

fn virtual_direction_key_press(direction string) tea.Cmd {
	return tea.msg_cmd(tea.KeyMsg{
		k_type: .special
		runes:  direction.runes()
	})
}

fn (mut m EditorModel2) execute_action_normal(action ChordAction) (tea.Cmd, bool) {
	count := if action.count == 0 { 1 } else { action.count }

	if op := action.operator {
		if is_text_object(action.motion) {
			return m.apply_text_object(op, action.motion, count)
		}
	}

	// mode-bound things that aren't really motions; handled before the
	// shared motion table so they can switch modes / insert text.
	match action.motion {
		'%' {
			// with a count, `%` goes to that percentage of the way down the
			// file, as in Vim. An operator with it, linewise there, waits on
			// a linewise range helper, so it does nothing meanwhile.
			if action.counted {
				if action.operator == none {
					m.jump_to_percent(count)
				}
				return tea.no_cmd, false
			}
			if op := action.operator {
				r := m.matching_bracket_range() or { return tea.no_cmd, false }
				apply_operator(m.doc_controller, m.doc_id, op, r)
				m.doc_controller.commit_undo_group(m.doc_id)
				return tea.no_cmd, false
			}
			m.jump_to_matching_bracket()
			return tea.no_cmd, false
		}
		'o' {
			// on a closed fold, the new line goes below all of it, and the
			// fold stays closed, as in Vim
			// the line opened is undone in one go with what's typed on it
			m.doc_controller.commit_undo_group(m.doc_id)
			m.doc_controller.begin_undo_group(m.doc_id)
			m.change_open = true
			cursor_line, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
			y := int(cursor_line)
			last := m.fold_end(y)
			folded := m.closed_folds.filter(y <= it.start && it.end <= last)
			m.doc_controller.jump_cursor_to_line(m.doc_id, u64(last))
			m.doc_controller.jump_cursor_to_line_end(m.doc_id)
			m.open_line()
			if folded.len > 0 {
				// the edit reached the fold's last line, which opens it, but
				// only to add lines below it
				m.sync_folds()
				mut closed := m.closed_folds.clone()
				closed << folded
				m.set_closed_folds(closed)
			}
			// TODO(tauraamui) [2026-06-17]: investigate a better less hacky feeling alternative method
			// to making the cursor be correctly positioned once we've manually inserted the previous line's
			// whitespace prefix than virtually emulating cursor right press. for example perhaps we could
			// make the cursor clamp method take the current mode into account? hmmm
			return tea.sequence(switch_mode(.insert), virtual_direction_key_press('right')), true
		}
		'I' {
			m.insert_line_pristine_indent = false
			m.doc_controller.jump_cursor_to_text_start(m.doc_id)
			return switch_mode(.insert), true
		}
		'A' {
			m.insert_line_pristine_indent = false
			m.doc_controller.jump_cursor_to_line_end(m.doc_id)
			return switch_mode(.insert), true
		}
		'line' {
			// only `dd` for now: `yy` and `cc` wait on apply_operator growing
			// yank and change, and mustn't delete the line meanwhile
			if action.operator or { rune(`d`) } != `d` {
				return tea.no_cmd, false
			}
			cursor_line, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
			for _ in 0 .. count {
				lines_before := m.doc_controller.line_count(m.doc_id)
				// a closed fold is one line to dd, as in Vim, so it all goes
				for _ in cursor_line .. u64(m.fold_end(int(cursor_line))) + 1 {
					// deleting the same line since each line delete will move
					// the next line up, into the delete
					m.doc_controller.delete_line(m.doc_id, cursor_line)
				}
				// nothing left below to delete: a count past the end of the
				// file must not go on deleting nothing for every step of it
				if m.doc_controller.line_count(m.doc_id) == lines_before {
					break
				}
			}
			m.doc_controller.commit_undo_group(m.doc_id)
			return tea.no_cmd, false
		}
		'u' {
			m.doc_controller.undo(m.doc_id)
			return tea.no_cmd, false
		}
		'x' {
			m.doc_controller.begin_undo_group(m.doc_id)
			for _ in 0 .. count {
				// x stops at the end of the line, as in Vim; past it, every
				// step left of a large count would delete nothing
				if !m.doc_controller.delete_char_at(m.doc_id) {
					break
				}
			}
			m.doc_controller.commit_undo_group(m.doc_id)
			return tea.no_cmd, false
		}
		'zo', 'zO', 'zc', 'zC', 'za', 'zA', 'zR', 'zM' {
			m.fold_command(action.motion)
			return tea.no_cmd, false
		}
		'zj', 'zk' {
			m.fold_jump(action.motion == 'zk', count)
			return tea.no_cmd, false
		}
		'j', 'k' {
			if action.operator == none {
				m.move_cursor_rows(if action.motion == 'j' { count } else { -count })
				return tea.no_cmd, false
			}
			// with an operator, j and k take in whole lines, and a closed
			// fold at either end is all taken in, as in Vim. Only `d` for
			// now, as with dd.
			if action.operator or { rune(`d`) } == `d` {
				m.delete_rows(if action.motion == 'j' { count } else { -count })
			}
			return tea.no_cmd, false
		}
		'zz' {
			// bare `zz` centers the viewport on the current line; an explicit
			// count jumps to that line first (matches v1's `zz` and the same
			// `count > 1` convention `G` already uses here).
			if count > 1 {
				m.doc_controller.jump_cursor_to_line(m.doc_id, u64(count - 1))
			}
			m.center_viewport_on_cursor()
			return tea.no_cmd, false
		}
		else {}
	}

	if op := action.operator {
		// operator + motion: resolve the motion's range, then apply operator.
		// `dd` arrives here as motion == 'line' (see chords.v) — left as a
		// TODO until a linewise range helper exists on Controller2.
		r := motion_range(m.doc_controller, m.doc_id, action.motion, count) or {
			return tea.no_cmd, false
		}
		apply_operator(m.doc_controller, m.doc_id, op, r)
		m.doc_controller.commit_undo_group(m.doc_id)
		return tea.no_cmd, false
	}

	apply_motion(m.doc_controller, m.doc_id, action.motion, count)
	return tea.no_cmd, false
}

// jump_to_percent is `{count}%`: the first non-blank of the line `count`
// percent of the way down the file. Over 100 percent, it stays put.
fn (mut m EditorModel2) jump_to_percent(count int) {
	if count > 100 {
		return
	}
	line_count := int(m.doc_controller.line_count(m.doc_id))
	line := (count * line_count + 99) / 100
	m.doc_controller.jump_cursor_to_line(m.doc_id, u64(if line > 0 { line - 1 } else { 0 }))
	m.doc_controller.jump_cursor_to_text_start(m.doc_id)
}

fn (mut m EditorModel2) execute_action_visual(action ChordAction) (tea.Cmd, bool) {
	count := if action.count == 0 { 1 } else { action.count }

	if op := action.operator {
		// in visual mode the selection IS the range — apply the operator
		// against it immediately and exit back to normal mode.
		if m.visual_linewise {
			m.apply_linewise_operator(op)
		} else {
			r := m.current_visual_range() or { return switch_mode(.normal), true }
			apply_operator(m.doc_controller, m.doc_id, op, r)
		}
		m.doc_controller.commit_undo_group(m.doc_id)
		return switch_mode(.normal), true
	}

	if is_text_object(action.motion) {
		m.select_text_object(action.motion, count)
		return tea.no_cmd, false
	}

	// pure motion in visual mode = extend selection. The cursor moves;
	// render_visual_selection derives the highlight from sel_start + cursor.
	if action.motion == '%' {
		if action.counted {
			m.jump_to_percent(count)
			return tea.no_cmd, false
		}
		m.jump_to_matching_bracket()
		return tea.no_cmd, false
	}
	if action.motion in ['j', 'k'] {
		m.move_cursor_rows(if action.motion == 'j' { count } else { -count })
		return tea.no_cmd, false
	}
	if action.motion in ['zj', 'zk'] {
		m.fold_jump(action.motion == 'zk', count)
		return tea.no_cmd, false
	}
	if action.motion in ['zo', 'zO', 'zc', 'zC', 'za', 'zA', 'zR', 'zM'] {
		sel_start_line := m.visual_sel_start_line or { return switch_mode(.normal), true }
		cursor_line, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
		mut first, mut last := sel_start_line, cursor_line
		if cursor_line < sel_start_line {
			first, last = cursor_line, sel_start_line
		}
		m.fold_command_visual(action.motion, int(first), int(last))
		return switch_mode(.normal), true
	}
	apply_motion(m.doc_controller, m.doc_id, action.motion, count)
	return tea.no_cmd, false
}

// apply_linewise_operator applies an operator across every full line spanned
// by the visual-line selection - same shape as the normal-mode `dd` handling
// in execute_action_normal, just driven by sel_start instead of a count.
fn (mut m EditorModel2) apply_linewise_operator(op u8) {
	sel_start_line := m.visual_sel_start_line or { return }
	cursor_line, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
	start_line := if sel_start_line < cursor_line { sel_start_line } else { cursor_line }
	last_line := if sel_start_line > cursor_line { sel_start_line } else { cursor_line }
	// a closed fold on the last line is all taken in
	end_line := u64(m.fold_end(int(last_line)))

	match op {
		`d` {
			for _ in start_line .. end_line + 1 {
				// deleting the same line repeatedly since each delete moves
				// the next line up into the deleted one
				m.doc_controller.delete_line(m.doc_id, start_line)
			}
		}
		else {}
	}
}

// invalidate_parser_cache throws away the line start states on the next
// render. Edits don't need it: they are picked up from the document's
// line change log by sync_parser_state_cache.
fn (mut m EditorModel2) invalidate_parser_cache() {
	m.parser_gen = 0
}

// sync_parser_state_cache brings parser_line_states up to date with every edit
// made to the document since it was last synced, by any editor showing it.
fn (mut m EditorModel2) sync_parser_state_cache() {
	changes := m.doc_controller.line_changes_since(m.doc_id, m.parser_gen)
	m.parser_gen = changes.gen
	if !changes.changed {
		return
	}
	if !changes.complete {
		m.rebuild_parser_state_cache()
		m.syntax_tree.reset()
		return
	}
	m.syntax_tree.edited(changes.change.first, changes.change.last, changes.change.delta)
	m.relex_parser_state_cache(changes.change.first, changes.change.last, changes.change.delta)
}

// DocLines gives the syntax tree a document's lines as they are in the
// buffer, without tabs expanded, so tree columns are buffer columns. Each line
// is decoded into the same buffer, which the tree reads only until it asks
// for the next.
struct DocLines {
	doc_id nanoid.ID
mut:
	doc_controller &documents.Controller2
	scratch        []u8
	runes          []rune
}

fn (mut d DocLines) line_count() int {
	return int(d.doc_controller.line_count(d.doc_id))
}

fn (mut d DocLines) line_runes(y int) []rune {
	d.doc_controller.line_runes_into(d.doc_id, u64(y), mut d.scratch, mut d.runes)
	return d.runes
}

fn (m EditorModel2) doc_lines() DocLines {
	return DocLines{
		doc_id:         m.doc_id
		doc_controller: m.doc_controller
	}
}

// syntax_ancestors gives the context tree nodes that contain `pos`,
// outermost first: e.g. the braces of the function the cursor is in, then a
// string inside it, then an interpolation inside that
fn (mut m EditorModel2) syntax_ancestors(pos syntax.Pos) []syntax.Node {
	m.sync_parser_state_cache()
	mut lines := m.doc_lines()
	return m.syntax_tree.ancestors(mut m.token_parser, mut lines, pos)
}

// syntax_find gives the tokens on lines `first` to `last` whose text is
// `word` and whose scope is one of `scopes` (any scope when empty), e.g. the
// calls to a function with [.function]
fn (mut m EditorModel2) syntax_find(word string, scopes []syntax.Scope, first int, last int) []syntax.Occurrence {
	m.sync_parser_state_cache()
	mut lines := m.doc_lines()
	return m.syntax_tree.find(mut m.token_parser, mut lines, word, scopes, first, last)
}

// syntax_token_at gives the token `pos` is in, e.g. a rune literal lexed as
// one string token
fn (mut m EditorModel2) syntax_token_at(pos syntax.Pos) ?syntax.Token {
	m.sync_parser_state_cache()
	mut lines := m.doc_lines()
	return m.syntax_tree.token_at(mut m.token_parser, mut lines, pos)
}

// rebuild_parser_state_cache forgets every line start state, so they are
// lexed again as lines are drawn
fn (mut m EditorModel2) rebuild_parser_state_cache() {
	m.parser_line_states.clear()
}

// ensure_parser_states extends parser_line_states until it holds the start
// state of line `y`
fn (mut m EditorModel2) ensure_parser_states(y int) {
	line_count := int(m.doc_controller.line_count(m.doc_id))
	target := if y < line_count { y } else { line_count - 1 }
	if target < m.parser_line_states.len {
		return
	}
	m.token_parser.reset()
	if m.parser_line_states.len == 0 {
		m.parser_line_states << m.token_parser.current_state()
	}
	m.token_parser.set_state(m.parser_line_states.last())
	mut lines := DrawnLines{}
	for m.parser_line_states.len <= target {
		m.token_parser.advance_state_runes(m.drawn_line(mut lines, m.parser_line_states.len - 1))
		m.parser_line_states << m.token_parser.current_state()
	}
	m.token_parser.reset()
}

// DrawnLines holds the buffers drawn_line reads lines into, so reading line
// after line allocates nothing once they're big enough
struct DrawnLines {
mut:
	scratch  []u8
	runes    []rune
	expanded []rune
}

// drawn_line gives line `y` with its tabs expanded, as view() draws it, so
// token rune indices line up 1:1 with on-screen columns. It's read into
// `lines`, and good only until the next line is read into it.
fn (m EditorModel2) drawn_line(mut lines DrawnLines, y int) []rune {
	m.doc_controller.line_runes_into(m.doc_id, u64(y), mut lines.scratch, mut lines.runes)
	return expand_tab_runes(lines.runes, m.config.tab_width, mut lines.expanded)
}

// expand_tab_runes gives `runes` with each tab replaced by `width` spaces, as
// expand_tabs does, building into `out` only when there's a tab to replace
@[direct_array_access]
fn expand_tab_runes(runes []rune, width int, mut out []rune) []rune {
	if `\t` !in runes {
		return runes
	}
	w := if width <= 0 { 1 } else { width }
	out.clear()
	for r in runes {
		if r != `\t` {
			out << r
			continue
		}
		for _ in 0 .. w {
			out << ` `
		}
	}
	return out
}

// relex_slack is how many lines past the view an edit relexes before leaving
// the rest to background lexing
const relex_slack = 256

// relex_parser_state_cache updates the line start states after lines `first`
// to `last` (counted after the edit) changed and the lines below them moved by
// `delta`. It relexes from `first` and stops at the first line below `last`
// whose start state comes out the same as before the edit, since every line
// after that one would too. A typed character costs one line; opening a block
// comment costs every line down to where the old and new states agree again,
// or to the end of the states held, whichever comes first.
// It returns false if it had to forget the states instead.
fn (mut m EditorModel2) relex_parser_state_cache(first_changed int, last_changed int, delta int) bool {
	line_count := int(m.doc_controller.line_count(m.doc_id))
	known := m.parser_line_states.len
	if first_changed + 1 >= known {
		// an edit can't change the start state of the line it starts on, so
		// every state held is still right
		return true
	}
	first := if first_changed > 0 { first_changed } else { 0 }
	// old index of the line now at last + 1, the first unchanged line
	tail_start := last_changed + 1 - delta
	if last_changed >= line_count - 1 || tail_start >= known {
		// the edit reaches past the states held: keep the ones above it
		m.parser_line_states.trim(first + 1)
		return true
	}
	if last_changed < first || tail_start <= first || known + delta > line_count {
		// the change doesn't fit the states held, so don't guess
		m.rebuild_parser_state_cache()
		return false
	}

	// make room for lines first+1 .. last, whose start states are recomputed
	// below; everything after them keeps its old state as a candidate
	old_mid := tail_start - (first + 1)
	new_mid := last_changed - first
	if new_mid > old_mid {
		m.parser_line_states.insert(first + 1, []syntax.State{len: new_mid - old_mid})
	}
	if new_mid < old_mid {
		m.parser_line_states.delete_many(first + 1, old_mid - new_mid)
	}

	// with states held for the whole document, opening a block comment would
	// relex every line below it here, so past the view the states are let go
	// for background lexing to redo. The view ends further down when closed
	// folds are in it.
	limit := m.rows_down(m.top_line, m.viewport_height) + relex_slack
	m.token_parser.reset()
	m.token_parser.set_state(m.parser_line_states[first])
	mut lines := DrawnLines{}
	for y in first .. m.parser_line_states.len - 1 {
		m.token_parser.advance_state_runes(m.drawn_line(mut lines, y))
		next := m.token_parser.current_state()
		if y + 1 > last_changed && m.parser_line_states[y + 1] == next {
			break
		}
		m.parser_line_states[y + 1] = next
		if y + 1 >= limit {
			m.parser_line_states.trim(y + 2)
			break
		}
	}
	m.token_parser.reset()
	return true
}

fn (m EditorModel2) current_visual_range() ?cursor.Range {
	sel_start_line := m.visual_sel_start_line or { return none }
	sel_start_col := m.visual_sel_start_col or { return none }
	cursor_line, cursor_col := m.doc_controller.cursor_line_and_x(m.doc_id)

	mut start_line, mut start_col := sel_start_line, sel_start_col
	mut end_line, mut end_col := cursor_line, cursor_col
	if cursor_line < sel_start_line || (cursor_line == sel_start_line && cursor_col < sel_start_col) {
		start_line, start_col = cursor_line, cursor_col
		end_line, end_col = sel_start_line, sel_start_col
	}

	// visual mode selection is always inclusive of the character under the
	// cursor at both ends (unlike normal-mode motions, which are mostly
	// exclusive) - bump the endpoint by one so it survives the exclusive
	// delete_range/apply_operator boundary, same as `$` does for d$.
	return cursor.Range{
		start: cursor.Pos.new(int(start_col), int(start_line))
		end:   cursor.Pos.new(int(end_col) + 1, int(end_line))
	}
}

// scroll_to_cursor scrolls the view to show the cursor, opening any closed
// fold it's hidden in
fn (mut m EditorModel2) scroll_to_cursor() {
	m.reveal_cursor()
	cursor_line_u, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
	cursor_line := int(cursor_line_u)
	if m.viewport_height <= 0 {
		m.top_line = cursor_line
		return
	}

	m.reach_rows(cursor_line, m.viewport_height)
	m.top_line = m.shown_line(m.top_line)
	if cursor_line < m.top_line {
		m.top_line = cursor_line
	}
	// the cursor's line is shown, so after the scroll up it's never past
	// the bottom row
	if cursor_line > m.rows_down(m.top_line, m.viewport_height - 1) {
		m.top_line = m.rows_up(cursor_line, m.viewport_height - 1)
	}
	m.clamp_top_line()
}

// clamp_top_line keeps the view from scrolling further down than the end of
// the document can fill
fn (mut m EditorModel2) clamp_top_line() {
	line_count := int(m.doc_controller.line_count(m.doc_id))
	// a view with lines below its last row is filled, and after zM, only a
	// view near the end has the end's folds to reach
	m.reach_rows(m.top_line, m.viewport_height)
	if m.top_line >= 0 && m.top_line < line_count
		&& m.line_below(m.rows_down(m.top_line, m.viewport_height - 1)) < line_count {
		return
	}
	m.reach_rows(line_count - 1, m.viewport_height)
	max_top := m.rows_up(line_count - 1, m.viewport_height - 1)
	if m.top_line > max_top {
		m.top_line = max_top
	}
	if m.top_line < 0 {
		m.top_line = 0
	}
}

// scroll_page_up implements ctrl+u: scrolls the viewport up by half a page
// and moves the cursor to keep its position relative to the new viewport
// (a quarter of the way down), mirroring v1's ctrl+u handling.
fn (mut m EditorModel2) scroll_page_up() {
	if m.viewport_height <= 0 {
		return
	}
	m.sync_folds()
	m.reach_rows(m.top_line, m.viewport_height)
	m.top_line = m.rows_up(m.top_line, m.viewport_height / 2)
	target_line := m.rows_down(m.top_line, m.viewport_height / 4)
	cursor_line, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
	m.doc_controller.move_cursor_lines(m.doc_id, target_line - int(cursor_line))
}

// scroll_page_down implements ctrl+d: scrolls the viewport down by half a
// page and moves the cursor to keep its position relative to the new
// viewport (three quarters of the way down), mirroring v1's ctrl+d handling.
fn (mut m EditorModel2) scroll_page_down() {
	if m.viewport_height <= 0 {
		return
	}
	m.sync_folds()
	m.reach_rows(m.top_line, m.viewport_height * 2)
	m.top_line = m.rows_down(m.top_line, m.viewport_height / 2)
	target_line := m.rows_down(m.top_line, m.viewport_height * 3 / 4)
	cursor_line, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
	m.doc_controller.move_cursor_lines(m.doc_id, target_line - int(cursor_line))
}

// center_viewport_on_cursor mirrors v1's center_cursor_line: puts the
// current line in the middle of the viewport, clamped so top_line never
// scrolls past what the buffer can fill.
fn (mut m EditorModel2) center_viewport_on_cursor() {
	cursor_line_u, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
	cursor_line := int(cursor_line_u)
	if m.viewport_height <= 0 {
		m.top_line = if cursor_line > 0 { cursor_line } else { 0 }
		return
	}
	m.reveal_cursor()
	m.reach_rows(cursor_line, m.viewport_height)
	m.top_line = m.rows_up(cursor_line, m.viewport_height / 2)
	m.clamp_top_line()
}

fn (mut m EditorModel2) clamp_cursor_to_line_end() {
	cursor_line, cursor_col := m.doc_controller.cursor_line_and_x(m.doc_id)
	line_bytes := m.doc_controller.get_line_bytes(m.doc_id, cursor_line) or { return }
	runes := line_bytes.bytestr().runes()
	mut grapheme_count := u64(0)
	mut i := 0
	for i < runes.len {
		i = next_grapheme_rune_index(runes, i)
		grapheme_count += 1
	}
	if grapheme_count == 0 {
		return
	}
	if cursor_col >= grapheme_count {
		m.doc_controller.internal_move_cursor_left(m.doc_id)
	}
}

fn (mut m EditorModel2) view(mut ctx tea.Context) {
	m.sync_folds()
	rows := m.screen_lines()
	relative_line_numbers := if m.config.relative_line_numbers { m.in_focus } else { false }
	offset_id := m.render_line_numbers(mut ctx, relative_line_numbers, rows)
	defer { ctx.clear_offsets_from(offset_id) }
	m.render_syntax_highlighting(mut ctx, rows)
	m.render_cursor_line_highlight(mut ctx, rows)
	m.render_matching_brackets(mut ctx, rows)
	m.render_visual_selection(mut ctx, rows)
	m.render_cursor_block(mut ctx, rows)
	for row, y in rows {
		line_bytes := m.doc_controller.get_line_bytes(m.doc_id, u64(y)) or { []u8{} }
		text := expand_tabs(line_bytes, m.config.tab_width)
		ctx.draw_text(0, row, text)
		if f := m.closed_fold_at(y) {
			m.render_fold_marker(mut ctx, row, utf8_str_visible_length(text), f)
		}
	}
}

// render_fold_marker draws, after the text of a closed fold's first line, how
// many lines the fold holds
fn (m EditorModel2) render_fold_marker(mut ctx tea.Context, row int, x int, f Fold) {
	ctx.set_color(m.config.theme.syntax_comment)
	ctx.draw_text(x, row, ' ··· ${f.end - f.start + 1} lines')
	ctx.reset_color()
}

// runes_visible_width is how many columns `runes` take on screen. Printable
// ASCII takes one each, which is nearly all code, and is counted directly:
// the builtin measure looks every rune up in Unicode's tables.
@[direct_array_access]
fn runes_visible_width(runes []rune) int {
	for r in runes {
		if r < ` ` || r > `~` {
			return utf8_str_visible_length(runes.string())
		}
	}
	return runes.len
}

fn expand_tabs(line_bytes []u8, width int) string {
	w := if width <= 0 { 1 } else { width }
	return line_bytes.bytestr().replace('\t', ' '.repeat(w))
}

fn (m EditorModel2) render_line_numbers(mut ctx tea.Context, relative_line_numbers bool, rows []int) int {
	cursor_line, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
	offset_id := ctx.push_offset(tea.Offset{ x: line_number_gutter_width(rows, m.top_line) })

	// relative numbers count rows, so a closed fold counts as one line, as
	// it does to j and k
	cursor_row := screen_row(rows, int(cursor_line)) or { -1 }
	ctx.set_color(m.config.theme.syntax_comment)
	for row, y in rows {
		line_nr := row_number_label(row, cursor_row, y, int(cursor_line), relative_line_numbers)
		ctx.draw_text(-1 - line_nr.len, row, line_nr)
	}
	ctx.reset_color()

	return offset_id
}

// line_number_gutter_width is how many columns the line numbers of `rows`
// take, wide enough for the last of them, and a column after it. With no rows,
// it's as wide as the number of `top_line`, the line the view starts on.
fn line_number_gutter_width(rows []int, top_line int) int {
	last := if rows.len > 0 { rows.last() } else { top_line }
	return num_digits(last + 1) + 1
}

// row_number_label is the number drawn on row `row`, which shows line `y`.
// Relative numbers count rows from the cursor's, `cursor_row`, or with the
// cursor off the view, lines from its line.
fn row_number_label(row int, cursor_row int, y int, cursor_line int, relative_line_numbers bool) string {
	if !relative_line_numbers || cursor_row < 0 || row == cursor_row {
		return resolve_line_number_label(y, cursor_line, relative_line_numbers)
	}
	if row < cursor_row {
		return '${cursor_row - row}'
	}
	return '${row - cursor_row}'
}

fn resolve_line_number_label(y int, cursor_line int, relative_line_numbers bool) string {
	if !relative_line_numbers || y == cursor_line { return '${y + 1}' }
	if y < cursor_line { return '${cursor_line - y}' }
	return '${y - cursor_line}'
}

fn (mut m EditorModel2) render_syntax_highlighting(mut ctx tea.Context, rows []int) {
	if m.lang_syn.name.len == 0 || rows.len == 0 {
		return
	}

	m.sync_parser_state_cache()
	if m.scope_colours.len == 0 {
		m.scope_colours = scope_colours(m.config.theme)
	}

	m.token_parser.reset()
	mut lines := DrawnLines{}
	for row, y in rows {
		// below a closed fold, the lexing picks up from the next line shown
		if row == 0 || rows[row - 1] != y - 1 {
			m.ensure_parser_states(y)
			m.token_parser.reset()
			if y < m.parser_line_states.len {
				m.token_parser.set_state(m.parser_line_states[y])
			}
		}
		line := m.drawn_line(mut lines, y)
		line_tokens := m.token_parser.parse_line_runes(line)

		mut visual_x := 0
		for t in line_tokens {
			token_width := runes_visible_width(line[t.start()..t.end()])
			colour := m.scope_colours[int(t.scope())]
			if colour.set {
				ctx.set_color(colour.colour)
				ctx.draw_rect(visual_x, row, token_width, 1)
				ctx.reset_color()
			}
			visual_x += token_width
		}
	}

	m.token_parser.reset()
}

fn (m EditorModel2) render_cursor_line_highlight(mut ctx tea.Context, rows []int) {
	if !m.in_focus { return }
	cursor_line, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
	row := screen_row(rows, int(cursor_line)) or { return }
	ctx.set_bg_color(m.config.theme.cursor_line_bg)
	ctx.draw_rect(0, row, m.viewport_width, 1)
	ctx.reset_bg_color()
}

fn (m EditorModel2) render_cursor_block(mut ctx tea.Context, rows []int) {
	if !m.in_focus { return }
	cursor_line, cursor_col := m.doc_controller.cursor_line_and_x(m.doc_id)
	row := screen_row(rows, int(cursor_line)) or { return }
	visual_x, cursor_width := m.visual_x_and_cluster_width_for(cursor_line, cursor_col)

	default_bg_color := ctx.get_default_bg_color() or { palette.matte_black_bg_color }
	ctx.set_bg_color(palette.fg_color(default_bg_color))
	ctx.set_color(default_bg_color)
	ctx.draw_rect(visual_x, row, cursor_width, 1)
	ctx.reset_bg_color()
	ctx.reset_color()
}

fn (m EditorModel2) render_visual_selection(mut ctx tea.Context, rows []int) {
	sel_start_line := m.visual_sel_start_line or { return }
	sel_start_col := m.visual_sel_start_col or { return }
	cursor_line, cursor_col := m.doc_controller.cursor_line_and_x(m.doc_id)

	mut start_line, mut start_col := sel_start_line, sel_start_col
	mut end_line, mut end_col := cursor_line, cursor_col
	if cursor_line < sel_start_line || (cursor_line == sel_start_line && cursor_col < sel_start_col) {
		start_line, start_col = cursor_line, cursor_col
		end_line, end_col = sel_start_line, sel_start_col
	}

	ctx.set_bg_color(m.config.theme.highlight_bg_color)
	defer { ctx.reset_bg_color() }
	ctx.set_color(palette.fg_color(m.config.theme.highlight_bg_color)) // set fg color to inverse shade of bg
	defer { ctx.reset_color() }

	start_visual_x, _ := m.visual_x_and_cluster_width_for(start_line, start_col)
	end_visual_x, end_cluster_width := m.visual_x_and_cluster_width_for(end_line, end_col)

	for row, y in rows {
		// a closed fold's row stands for all of its lines
		last := if f := m.closed_fold_at(y) { f.end } else { y }
		if last < int(start_line) || y > int(end_line) {
			continue
		}
		if m.visual_linewise {
			ctx.draw_rect(0, row, m.viewport_width, 1)
			continue
		}
		// from the selection's start on its first line, to its end on its
		// last, and the whole width between
		from := if y == int(start_line) { start_visual_x } else { 0 }
		to := if y == int(end_line) { end_visual_x + end_cluster_width } else { m.viewport_width }
		ctx.draw_rect(from, row, to - from, 1)
	}
}

fn (m EditorModel2) visual_x_and_cluster_width_for(line u64, col u64) (int, int) {
	line_bytes := m.doc_controller.get_line_bytes(m.doc_id, line) or { []u8{} }
	runes := line_bytes.bytestr().runes()
	c := int(col) // logical column == grapheme cluster index

	// grapheme-cluster index -> rune prefix length, so visible-width
	// measurement covers ZWJ sequences and variation selectors as one glyph.
	prefix_end := rune_index_after_graphemes(runes, c)
	prefix := runes[..prefix_end].string().replace('\t', ' '.repeat(if m.config.tab_width <= 0 {
		1
	} else {
		m.config.tab_width
	}))
	visual_x := utf8_str_visible_length(prefix)

	// width of the cluster at the column (min 1 so the block stays visible)
	cluster_width := if prefix_end < runes.len {
		cluster_end := next_grapheme_rune_index(runes, prefix_end)
		if runes[prefix_end] == `\t` {
			if m.config.tab_width <= 0 {
				1
			} else {
				m.config.tab_width
			}
		} else {
			w := utf8_str_visible_length(runes[prefix_end..cluster_end].string())
			if w < 1 {
				1
			} else {
				w
			}
		}
	} else {
		1
	}

	return visual_x, cluster_width
}

fn (m EditorModel2) width() int {
	return m.viewport_width
}

fn (m EditorModel2) height() int {
	return m.viewport_height
}

struct EditorData2 {
	id            nanoid.ID
	file_path     string
	cursor_row    int
	cursor_col    int
	chord_display string
	width         int
	height        int
}

fn (m EditorModel2) data() EditorData2 {
	cursor_line, cursor_x := m.doc_controller.cursor_line_and_x(m.doc_id)
	return EditorData2{
		id:        m.id
		file_path: m.file_path

		cursor_row: int(cursor_line)
		cursor_col: int(cursor_x)

		chord_display: m.chord.display()

		width:  m.viewport_width
		height: m.viewport_height
	}
}

fn (m EditorModel2) debug_data() DebugData {
	cursor_line, cursor_x := m.doc_controller.cursor_line_and_x(m.doc_id)
	return DebugData{
		name: 'active editor data'
		data: {
			'id':         '${m.id}'
			'doc_id':     '${m.doc_id}'
			'cursor_row': '${int(cursor_line)}'
			'cursor_col': '${int(cursor_x)}'
			'width':      '${m.viewport_width}'
			'height':     '${m.viewport_height}'
		}
	}
}

fn (m EditorModel2) clone() tea.Model {
	return EditorModel2{
		...m
	}
}

fn rune_index_after_graphemes(runes []rune, n int) int {
	mut i := 0
	mut count := 0
	for i < runes.len && count < n {
		i = next_grapheme_rune_index(runes, i)
		count += 1
	}
	return i
}

fn next_grapheme_rune_index(runes []rune, start int) int {
	if start >= runes.len {
		return start
	}
	mut i := start + 1
	for i < runes.len {
		r := runes[i]
		if r == rune(0x200D) {
			// ZWJ glues to the following codepoint
			i += 1
			if i < runes.len {
				i += 1
			}
			continue
		}
		if is_rune_extender(r) {
			i += 1
			continue
		}
		break
	}
	return i
}

fn is_rune_extender(r rune) bool {
	if r >= rune(0x0300) && r <= rune(0x036F) {
		return true
	}
	if r >= rune(0xFE00) && r <= rune(0xFE0F) {
		return true
	}
	return false
}

struct EditorModel2Msg {
	active_id nanoid.ID
	msg       tea.Msg
	mode      petal.Mode
}

struct QueryEditorData2Msg {}

fn query_editor_data2(id nanoid.ID) tea.Cmd {
	return tea.msg_cmd(EditorModel2Msg{
		active_id: id
		msg:       QueryEditorData2Msg{}
	})
}

struct EditorData2ResultMsg {
	data EditorData2
}

fn editor_data2(data EditorData2) tea.Cmd {
	return tea.msg_cmd(EditorData2ResultMsg{data})
}

fn write_to_disk2(id nanoid.ID) tea.Cmd {
	return tea.msg_cmd(EditorModel2Msg{
		active_id: id
		msg:       WriteToDiskMsg{}
	})
}

// load_syntax2 is load_syntax for the rewritten editor. It resolves eagerly for
// the same reason: a deferred lookup would need a closure over its arguments,
// and those are never released. See load_syntax.
fn load_syntax2(editor_id nanoid.ID, file_path string) tea.Cmd {
	syn, err_msg := resolve_syntax(file_path)
	return tea.msg_cmd(EditorModel2Msg{
		active_id: editor_id
		msg:       SyntaxLoadedMsg{
			syn:     syn
			err_msg: err_msg
		}
	})
}
