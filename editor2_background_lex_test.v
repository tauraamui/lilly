module main

import arrays
import os
import time
import bobatea as tea
import lib.cfg
import lib.documents
import lib.syntax

// lex_test_file writes `lines` lines of V, functions holding strings
fn lex_test_file(lines int) string {
	path := os.join_path(os.temp_dir(), 'lilly_background_lex_${time.now().unix_nano()}.v')
	mut out := []string{cap: lines}
	for i in 0 .. lines {
		out << match i % 5 {
			0 { 'fn f${i}() {' }
			4 { '}' }
			else { '\tx := "a"' }
		}
	}
	os.write_file(path, out.join('\n')) or { panic('failed to write temp file: ${err}') }
	return path
}

fn lex_test_editor(c &documents.Controller2, path string) EditorModel2 {
	doc_id := c.open_document(path) or { panic('failed to open temp document: ${err}') }
	v_syntax := syntax.resolve_from_extension('main.v') or { panic(err) }
	mut m := EditorModel2{
		id:              'lex-test'
		config:          EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:          doc_id
		doc_controller:  c
		lang_syn:        v_syntax
		viewport_height: 20
	}
	m.token_parser.set_syntax(v_syntax)
	return m
}

// lex_states_of describes an editor's line states by their context stacks
fn lex_states_of(m EditorModel2) []string {
	return m.parser_line_states.map(m.token_parser.state_name(it))
}

// fresh_lex_states is what lexing the whole document from scratch gives
fn fresh_lex_states(c &documents.Controller2, path string) []string {
	mut fresh := lex_test_editor(c, path)
	fresh.ensure_parser_states(int(c.line_count(fresh.doc_id)) - 1)
	return lex_states_of(fresh)
}

// lex_until_done runs slices until nothing is left, returning how many it took
fn lex_until_done(mut m EditorModel2) int {
	mut slices := 0
	for m.lex_pending() {
		m.background_lex(background_lex_budget)
		slices++
		assert slices < 10_000, 'background lexing never finishes'
	}
	return slices
}

fn test_background_lexing_fills_the_line_states_and_the_tree() {
	path := lex_test_file(3000)
	defer { os.rm(path) or {} }
	mut c := &documents.Controller2{}
	mut m := lex_test_editor(c, path)
	assert m.lex_pending()
	lex_until_done(mut m)
	assert m.parser_line_states.len == 3000
	assert m.syntax_tree.covers(3000)
	assert lex_states_of(m) == fresh_lex_states(c, path)
	// and with nothing to do, a slice does nothing
	m.background_lex(background_lex_budget)
	assert m.parser_line_states.len == 3000
}

fn test_a_slice_stops_at_its_budget() {
	path := lex_test_file(200_000)
	defer { os.rm(path) or {} }
	mut c := &documents.Controller2{}
	mut m := lex_test_editor(c, path)
	sw := time.new_stopwatch()
	m.background_lex(background_lex_budget)
	took := sw.elapsed()
	assert m.parser_line_states.len > 0
	assert m.parser_line_states.len < 200_000, 'lexed it all in one slice'
	// one step of lines past the budget at most, with room for a slow machine
	assert took < background_lex_budget * 10
}

fn test_a_slice_of_long_lines_stops_near_its_budget() {
	path := os.join_path(os.temp_dir(), 'lilly_background_lex_long_${time.now().unix_nano()}.v')
	line := '\tx := f(a, "b") + ' + 'c + '.repeat(1000)
	os.write_file(path, [line].repeat(5000).join('\n')) or {
		panic('failed to write temp file: ${err}')
	}
	defer { os.rm(path) or {} }
	mut c := &documents.Controller2{}
	mut m := lex_test_editor(c, path)
	sw := time.new_stopwatch()
	m.background_lex(background_lex_budget)
	took := sw.elapsed()
	assert m.parser_line_states.len > 1
	// the step shrinks to fit long lines in the budget, where a fixed 512
	// lines of them took 6 budgets in a prod build and over 30 in a debug
	// one. As in the test above, there's room for a slow or busy machine.
	assert took < background_lex_budget * 10, 'took ${took}'
}

fn test_without_a_syntax_there_is_nothing_to_lex() {
	path := lex_test_file(100)
	defer { os.rm(path) or {} }
	mut c := &documents.Controller2{}
	mut m := lex_test_editor(c, path)
	m.lang_syn = syntax.noop_syntax
	assert !m.lex_pending()
}

fn test_an_edit_relexes_no_further_than_the_view_and_background_lexing_redoes_the_rest() {
	path := lex_test_file(5000)
	defer { os.rm(path) or {} }
	mut c := &documents.Controller2{}
	mut m := lex_test_editor(c, path)
	lex_until_done(mut m)

	// opening a block comment at the top changes how every line below lexes
	c.insert_string(m.doc_id, '/*')
	m.sync_parser_state_cache()
	limit := m.top_line + m.viewport_height + relex_slack
	assert m.parser_line_states.len == limit + 1
	expected := fresh_lex_states(c, path)
	assert lex_states_of(m) == expected[..m.parser_line_states.len]
	assert m.lex_pending()

	lex_until_done(mut m)
	assert lex_states_of(m) == expected
	assert m.syntax_tree.covers(5000)
}

fn lex_test_workspace(path string) (EditorWorkspaceModel2, &documents.Controller2) {
	mut c := &documents.Controller2{}
	mut w := EditorWorkspaceModel2.new(EditorWorkspaceConfig.new(cfg.default_config), c)
	_, cmd := w.open_file_update(OpenFileMsg{
		file_path: path
	})
	// the editor's syntax arrives in a message its init sends
	for msg in cmd.delivered_msgs() {
		if msg is EditorModel2Msg && msg.msg is SyntaxLoadedMsg {
			w, _ = workspace_update(mut w, msg)
		}
	}
	return w, c
}

// workspace_update updates `w` as the app does, keeping the model it gives
fn workspace_update(mut w EditorWorkspaceModel2, msg tea.Msg) (EditorWorkspaceModel2, tea.Cmd) {
	model, cmd := w.update(msg)
	if model is EditorWorkspaceModel2 {
		return model, cmd
	}
	panic('not a workspace')
}

// ticks_in counts the ticks among a command's commands
fn ticks_in(cmd tea.Cmd) int {
	return match cmd {
		tea.TickCmd { 1 }
		tea.BatchCmd { arrays.sum(cmd.cmds.map(ticks_in(it))) or { 0 } }
		tea.SequenceCmd { arrays.sum(cmd.cmds.map(ticks_in(it))) or { 0 } }
		else { 0 }
	}
}

fn workspace_editor(w EditorWorkspaceModel2) EditorModel2 {
	editor := w.editors[w.active_editor_id] or { panic('no editor') }
	if editor is EditorModel2 {
		return editor
	}
	panic('not an editor')
}

fn test_the_workspace_keeps_one_tick_going_until_lexing_is_done() {
	path := lex_test_file(50_000)
	defer { os.rm(path) or {} }
	mut w, _ := lex_test_workspace(path)
	assert w.lex_ticking, 'opening the file started lexing'

	// any other message leaves the one tick on its way alone
	mut cmd := tea.no_cmd
	w, cmd = workspace_update(mut w, tea.FocusedMsg{})
	assert ticks_in(cmd) == 0

	mut ticks := 0
	for {
		w, cmd = workspace_update(mut w, BackgroundLexTickMsg{})
		n := ticks_in(cmd)
		assert n <= 1
		if n == 0 {
			break
		}
		ticks++
		assert ticks < 10_000, 'background lexing never finishes'
	}
	assert ticks > 1, 'all of it in one slice'
	assert !w.lex_ticking
	e := workspace_editor(w)
	assert e.parser_line_states.len == 50_000
	assert e.syntax_tree.covers(50_000)
}

fn test_lexing_goes_on_under_a_dialog() {
	path := lex_test_file(50_000)
	defer { os.rm(path) or {} }
	mut w, _ := lex_test_workspace(path)
	w, _ = workspace_update(mut w, OpenDialogMsg{
		model: VersionModel{
			theme: cfg.default_config.theme
		}
	})
	assert w.dialog_model != none
	before := workspace_editor(w).parser_line_states.len
	mut cmd := tea.no_cmd
	w, cmd = workspace_update(mut w, BackgroundLexTickMsg{})
	assert workspace_editor(w).parser_line_states.len > before
	assert ticks_in(cmd) == 1
}

fn test_the_workspace_keeps_what_checking_for_lexing_synced() {
	path := lex_test_file(5000)
	defer { os.rm(path) or {} }
	mut w, mut c := lex_test_workspace(path)
	mut cmd := tea.no_cmd
	for w.lex_ticking {
		w, cmd = workspace_update(mut w, BackgroundLexTickMsg{})
	}
	e := workspace_editor(w)
	assert e.parser_line_states.len == 5000

	// an edit at the top changes how every line below lexes. Looking for
	// lexing to do syncs the editor, trimming its states past the view, and
	// the editor kept has to be the synced one, not one holding stale states
	c.insert_string(e.doc_id, '/*')
	w, cmd = workspace_update(mut w, tea.FocusedMsg{})
	assert ticks_in(cmd) == 1
	synced := workspace_editor(w)
	assert synced.parser_line_states.len == synced.top_line + synced.viewport_height +
		relex_slack + 1

	for w.lex_ticking {
		w, cmd = workspace_update(mut w, BackgroundLexTickMsg{})
	}
	assert lex_states_of(workspace_editor(w)) == fresh_lex_states(c, path)
}

// TickSpy is a split that counts the background lex ticks it's given
struct TickSpy {
mut:
	ticks &int
}

fn (mut s TickSpy) init() tea.Cmd {
	return tea.no_cmd
}

fn (mut s TickSpy) update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if msg is BackgroundLexTickMsg {
		unsafe {
			*s.ticks += 1
		}
	}
	return s.clone(), tea.no_cmd
}

fn (mut s TickSpy) view(mut ctx tea.Context) {}

fn (s TickSpy) clone() tea.Model {
	return TickSpy{
		ticks: s.ticks
	}
}

fn (s TickSpy) debug_data() DebugData {
	return DebugData{
		name: 'tick spy'
	}
}

fn (s TickSpy) width() int {
	return 0
}

fn (s TickSpy) height() int {
	return 0
}

fn test_the_tick_stops_at_the_workspace() {
	path := lex_test_file(50_000)
	defer { os.rm(path) or {} }
	mut w, _ := lex_test_workspace(path)
	mut ticks := 0
	w.editors['spy'] = TickSpy{
		ticks: &ticks
	}
	before := workspace_editor(w).parser_line_states.len
	mut cmd := tea.no_cmd
	w, cmd = workspace_update(mut w, BackgroundLexTickMsg{})
	assert workspace_editor(w).parser_line_states.len > before, 'the tick still lexes'
	assert ticks_in(cmd) == 1, 'and keeps lexing going'
	assert ticks == 0, 'no split is handed the tick'
}

fn test_slices_are_short_while_keys_are_coming() {
	assert lex_slice_budget(0) == background_lex_budget
	assert lex_slice_budget(background_lex_typing_window - time.millisecond) == background_lex_budget
	assert lex_slice_budget(background_lex_typing_window) == background_lex_idle_budget
	assert background_lex_idle_budget > background_lex_budget
}

fn test_the_workspace_notes_when_a_key_came() {
	path := lex_test_file(50)
	defer { os.rm(path) or {} }
	mut w, _ := lex_test_workspace(path)
	assert w.last_key_mono == 0
	before := time.sys_mono_now()
	w, _ = workspace_update(mut w, tea.KeyMsg{
		k_type: .runes
		runes:  [`j`]
	})
	assert w.last_key_mono >= before
	// a slice straight after it keeps to the short budget
	assert lex_slice_budget(time.Duration(i64(time.sys_mono_now() - w.last_key_mono))) == background_lex_budget
}
