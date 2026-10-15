module main

import os
import time
import bobatea as tea
import lib.cfg
import lib.documents
import lib.syntax

const syntax_tree_view_sample = 'fn main() {
	x := "a \${b(1)} c"
	/* c */
}
'

fn syntax_tree_test_file() string {
	path := os.join_path(os.temp_dir(), 'lilly_syntax_tree_${time.now().unix_nano()}.v')
	os.write_file(path, syntax_tree_view_sample) or { panic('failed to write temp file: ${err}') }
	return path
}

fn tree_view_key(s string) tea.KeyMsg {
	return tea.KeyMsg{
		k_type: if s == 'enter' { tea.KeyType.special } else { tea.KeyType.runes }
		runes:  s.runes()
	}
}

fn tree_view_workspace(path string) (EditorWorkspaceModel2, &documents.Controller2) {
	mut c := &documents.Controller2{}
	mut w := EditorWorkspaceModel2.new(EditorWorkspaceConfig.new(cfg.default_config), c)
	w.open_file_update(OpenFileMsg{
		file_path: path
	})
	return w, c
}

fn tree_view_of(w EditorWorkspaceModel2, editor_id string) ?SyntaxTreeModel {
	for id in w.syntax_trees_of(editor_id) {
		view := w.editors[id] or { continue }
		if view is SyntaxTreeModel {
			return view
		}
	}
	return none
}

fn row_names(view SyntaxTreeModel) []string {
	return view.spans.map('${'  '.repeat(it.node.depth)}${it.node.name}')
}

fn test_inspect_tree_toggles_a_view_beside_the_editor() {
	path := syntax_tree_test_file()
	defer { os.rm(path) or {} }
	mut w, _ := tree_view_workspace(path)
	editor_id := w.active_editor_id

	w.toggle_syntax_tree_update(ToggleSyntaxTreeMsg{editor_id})
	assert w.editors.len == 2
	assert w.active_editor_id == editor_id, 'the editor keeps focus'
	view := tree_view_of(w, editor_id) or { panic('no view opened') }
	assert view.doc_id == (w.editors[editor_id] or { panic('no editor') } as EditorModel2).doc_id

	w.toggle_syntax_tree_update(ToggleSyntaxTreeMsg{editor_id})
	assert w.editors.len == 1
	assert w.syntax_trees_of(editor_id).len == 0
}

fn test_inspect_tree_from_the_view_closes_it() {
	path := syntax_tree_test_file()
	defer { os.rm(path) or {} }
	mut w, _ := tree_view_workspace(path)
	editor_id := w.active_editor_id
	w.toggle_syntax_tree_update(ToggleSyntaxTreeMsg{editor_id})
	view_id := w.syntax_trees_of(editor_id)[0]
	w.active_editor_id = view_id

	w.toggle_syntax_tree_update(ToggleSyntaxTreeMsg{view_id})
	assert w.editors.len == 1
	assert w.active_editor_id == editor_id
}

fn test_closing_an_editor_closes_its_view() {
	path := syntax_tree_test_file()
	defer { os.rm(path) or {} }
	mut w, _ := tree_view_workspace(path)
	first_id := w.active_editor_id
	w.open_editor_in_split_update(OpenEditorInSplitMsg{first_id, .horizontal})
	second_id := w.active_editor_id
	w.toggle_syntax_tree_update(ToggleSyntaxTreeMsg{second_id})
	assert w.editors.len == 3

	w.close_editor_update(CloseEditor2Msg{
		active_editor_id:   second_id
		editor_id_to_close: second_id
	})
	assert w.editors.len == 1
	assert w.active_editor_id == first_id
}

fn test_closing_an_editor_beside_a_view_focuses_an_editor() {
	path := syntax_tree_test_file()
	defer { os.rm(path) or {} }
	mut w, _ := tree_view_workspace(path)
	first_id := w.active_editor_id
	w.open_editor_in_split_update(OpenEditorInSplitMsg{first_id, .horizontal})
	second_id := w.active_editor_id
	// the view splits the first editor's leaf, so the layout is
	// [[first, view], second], and the neighbour that grows into the second
	// editor's space is the view
	w.toggle_syntax_tree_update(ToggleSyntaxTreeMsg{first_id})
	w.active_editor_id = second_id

	w.close_editor_update(CloseEditor2Msg{
		active_editor_id:   second_id
		editor_id_to_close: second_id
	})
	assert w.editors.len == 2
	assert w.active_editor_id == first_id
}

fn test_the_view_follows_the_document_cursor_and_edits() {
	path := syntax_tree_test_file()
	defer { os.rm(path) or {} }
	mut w, mut c := tree_view_workspace(path)
	editor_id := w.active_editor_id
	w.toggle_syntax_tree_update(ToggleSyntaxTreeMsg{editor_id})
	mut view := tree_view_of(w, editor_id) or { panic('no view opened') }
	view.height = 20

	// on the 1 in b(1)
	c.jump_cursor_to_line(view.doc_id, 1)
	for _ in 0 .. 12 {
		c.move_cursor_right(view.doc_id)
	}
	view.refresh()
	assert row_names(view) == ['function', '  params', '    ()', '  {}', '    double',
		'      interpolation', '        {}', '          ()', '    block_comment']
	assert view.labels[0] == 'function main'
	assert view.cursor_row == 7
	assert view.cursor_scope or { panic('no token') } == syntax.Scope.number
	assert span_range_label(view.spans[4]) == '[1, 6] - [1, 19]'

	// an edit anywhere shows up in the view
	c.jump_cursor_to_line(view.doc_id, 2)
	c.insert_string(view.doc_id, '"')
	view.refresh()
	assert row_names(view) == ['function', '  params', '    ()', '  {}', '    double',
		'      interpolation', '        {}', '          ()', '    double']
}

fn test_the_view_moves_the_cursor_to_the_node_picked() {
	path := syntax_tree_test_file()
	defer { os.rm(path) or {} }
	mut w, mut c := tree_view_workspace(path)
	editor_id := w.active_editor_id
	w.toggle_syntax_tree_update(ToggleSyntaxTreeMsg{editor_id})
	mut view := tree_view_of(w, editor_id) or { panic('no view opened') }
	view.height = 20

	// focusing the view picks the node the cursor is in: the block comment
	c.jump_cursor_to_line(view.doc_id, 2)
	view.update(EditorModel2Msg{
		active_id: view.id
		msg:       tea.FocusedMsg{}
	})
	assert view.selected == 8

	for _ in 0 .. 4 {
		view.update(EditorModelKeyMsg{ active_id: view.id, key_msg: tree_view_key('k') })
	}
	assert view.selected == 4
	view.update(EditorModelKeyMsg{ active_id: view.id, key_msg: tree_view_key('p') })
	assert view.selected == 3, 'p goes up to the function body'
	view.update(EditorModelKeyMsg{ active_id: view.id, key_msg: tree_view_key('j') })
	assert view.selected == 4

	_, cmd := view.update(EditorModelKeyMsg{ active_id: view.id, key_msg: tree_view_key('enter') })
	line, x := c.cursor_line_and_x(view.doc_id)
	assert line == 1 && x == 6, 'the cursor is on the string'
	mut activates := false
	for msg in cmd.delivered_msgs() {
		if msg is ActivateEditorMsg {
			activates = msg.editor_id == editor_id
		}
	}
	assert activates, 'enter goes back to the editor'

	// keys meant for another split are ignored
	view.update(EditorModelKeyMsg{ active_id: editor_id, key_msg: tree_view_key('j') })
	assert view.selected == 4
}

fn test_inspect_tree_is_a_command() {
	cmd := execute_command('editor-1', 'InspectTree')
	mut toggles := false
	for msg in cmd.delivered_msgs() {
		if msg is ToggleSyntaxTreeMsg {
			toggles = msg.editor_id == 'editor-1'
		}
	}
	assert toggles
}

fn test_a_row_names_what_its_node_defines() {
	mut parser := syntax.Parser{}
	parser.set_syntax(syntax.resolve_from_extension('main.v') or { panic(err) })
	mut tree := syntax.Tree{}
	mut src := TreeViewLines{
		lines: ['struct P {', '\tx int', '}', 'fn (p P) dist(q P) int {', '\tf := fn () { y := 1 }',
			'}']
	}
	spans := tree.outline(mut parser, mut src, 0, 5)
	defs := tree.definitions(mut parser, mut src, 0, 5)
	labels := span_labels(spans, defs)
	assert labels == ['struct P', '{}', 'function dist', 'params', '()', 'params', '()', '{}',
		'function', 'params', '()', '{}']
}

struct TreeViewLines {
mut:
	lines []string
}

fn (mut s TreeViewLines) line_count() int {
	return s.lines.len
}

fn (mut s TreeViewLines) line_runes(y int) []rune {
	return s.lines[y].runes()
}

fn test_labels_keep_up_with_many_definitions() {
	mut parser := syntax.Parser{}
	parser.set_syntax(syntax.resolve_from_extension('main.v') or { panic(err) })
	mut tree := syntax.Tree{}
	mut src := TreeViewLines{}
	for i in 0 .. 300 {
		src.lines << 'fn f${i}() { x := g(a, [1, 2], "s \${b(1)} c") }'
	}
	spans := tree.outline(mut parser, mut src, 0, 299)
	defs := tree.definitions(mut parser, mut src, 0, 299)
	sw := time.new_stopwatch()
	labels := span_labels(spans, defs)
	took := sw.elapsed()
	assert labels.filter(it.starts_with('function f')).len == 300
	assert labels[0] == 'function f0'
	// the view builds these every frame: each definition's context is found
	// once, not once per row, which took seconds here
	assert took < 50 * time.millisecond, 'took ${took}'
}

// tree_view_workspace_update updates `w` as the app does, keeping the model
// it gives
fn tree_view_workspace_update(mut w EditorWorkspaceModel2, msg tea.Msg) (EditorWorkspaceModel2, tea.Cmd) {
	model, cmd := w.update(msg)
	if model is EditorWorkspaceModel2 {
		return model, cmd
	}
	panic('not a workspace')
}

fn test_picking_a_node_out_of_the_editors_view_scrolls_it_there() {
	path := os.join_path(os.temp_dir(), 'lilly_syntax_tree_scroll_${time.now().unix_nano()}.v')
	mut lines := ['fn main() {']
	for i in 0 .. 300 {
		lines << '\tx${i} := 1'
	}
	lines << '}'
	os.write_file(path, lines.join('\n')) or { panic('failed to write temp file: ${err}') }
	defer { os.rm(path) or {} }
	mut w, mut c := tree_view_workspace(path)
	editor_id := w.active_editor_id
	w, _ = tree_view_workspace_update(mut w, tea.ResizedMsg{
		window_width:  160
		window_height: 50
	})
	w.toggle_syntax_tree_update(ToggleSyntaxTreeMsg{editor_id})
	mut view := tree_view_of(w, editor_id) or { panic('no view opened') }
	view.height = 50
	editor := w.editors[editor_id] or { panic('no editor') }
	mut e := editor as EditorModel2
	c.jump_cursor_to_line(e.doc_id, 250)
	e.scroll_to_cursor()
	w.editors[editor_id] = e
	assert e.top_line > 0

	// the function's row, at the top of the file
	view.update(EditorModel2Msg{
		active_id: view.id
		msg:       tea.FocusedMsg{}
	})
	view.select_row(0)
	_, cmd := view.update(EditorModelKeyMsg{ active_id: view.id, key_msg: tree_view_key('enter') })
	for msg in cmd.delivered_msgs() {
		mut next, follow := tree_view_workspace_update(mut w, msg)
		for m in follow.delivered_msgs() {
			next, _ = tree_view_workspace_update(mut next, m)
		}
		w = next
	}
	line, _ := c.cursor_line_and_x(e.doc_id)
	assert line == 0
	after := w.editors[editor_id] or { panic('no editor') }
	assert (after as EditorModel2).top_line == 0, 'the editor scrolled to its cursor'
}
