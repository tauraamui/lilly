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
import lib.documents
import lib.nanoid
import lib.palette
import lib.syntax

// syntax_tree_header_rows is the rows above the outline: a title, and what
// is under the document's cursor
const syntax_tree_header_rows = 2

// SyntaxTreeModel is a read only split showing the context tree of the
// document another editor shows, live, like Neovim's :InspectTree. It lists
// the nodes around the document's cursor, indented by depth, and highlights
// the innermost one the cursor is in. Focused, j/k pick a node and enter moves
// the cursor to it and goes back to the editor.
//
// It keeps its own tree and parser, synced from the document's line change log
// like any editor showing the document, so it follows edits made anywhere.
struct SyntaxTreeModel {
	id             nanoid.ID
	source_id      nanoid.ID
	doc_id         nanoid.ID
	file_path      string
	doc_controller &documents.Controller2
	config         EditorWorkspaceConfig
mut:
	lang_syn      syntax.Syntax
	parser        syntax.Parser
	tree          syntax.Tree
	gen           u64
	in_focus      bool
	width         int
	height        int
	scope_colours []ScopeColour
	// spans is the outline, cursor_row the row of the innermost node around
	// the cursor (-1 if none) and cursor_scope the scope of the token there,
	// as of the last refresh
	spans []syntax.Span
	// labels is each span's row text: its node's name, and for a function
	// or type, the name it defines
	labels       []string
	cursor_row   int
	cursor_pos   syntax.Pos
	cursor_scope ?syntax.Scope
	// selected is the row picked while focused, top_row the first row shown
	selected int
	top_row  int
}

fn SyntaxTreeModel.new(id nanoid.ID, source EditorModel2) SyntaxTreeModel {
	syn, _ := resolve_syntax(source.file_path)
	mut m := SyntaxTreeModel{
		id:             id
		source_id:      source.id
		doc_id:         source.doc_id
		file_path:      source.file_path
		doc_controller: source.doc_controller
		config:         source.config
		lang_syn:       syn
	}
	m.parser.set_syntax(syn)
	return m
}

fn (mut m SyntaxTreeModel) init() tea.Cmd {
	return tea.no_cmd
}

fn (mut m SyntaxTreeModel) update(msg tea.Msg) (tea.Model, tea.Cmd) {
	match msg {
		EditorModelKeyMsg {
			if msg.active_id == m.id {
				return m.key_update(msg.key_msg)
			}
		}
		EditorModel2Msg {
			inner := msg.msg
			match inner {
				tea.FocusedMsg {
					was_focused := m.in_focus
					m.in_focus = msg.active_id == m.id
					if m.in_focus && !was_focused {
						// start from the node the cursor is in
						m.refresh()
						m.selected = if m.cursor_row >= 0 { m.cursor_row } else { 0 }
					}
				}
				tea.ResizedMsg {
					// the workspace sends each split its own size
					m.width = inner.window_width
					m.height = inner.window_height
				}
				QueryEditorData2Msg {
					if msg.active_id == m.id {
						return m.clone(), editor_data2(m.data())
					}
				}
				else {}
			}
		}
		else {}
	}
	return m.clone(), tea.no_cmd
}

fn (mut m SyntaxTreeModel) key_update(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	m.refresh()
	match msg.string() {
		'j', 'down' {
			m.select_row(m.selected + 1)
		}
		'k', 'up' {
			m.select_row(m.selected - 1)
		}
		'g' {
			m.select_row(0)
		}
		'G' {
			m.select_row(m.spans.len - 1)
		}
		'p' {
			// up to the node this one is in
			if m.selected < m.spans.len {
				depth := m.spans[m.selected].node.depth
				for i := m.selected - 1; i >= 0; i-- {
					if m.spans[i].node.depth < depth {
						m.select_row(i)
						break
					}
				}
			}
		}
		'enter' {
			if m.selected < m.spans.len {
				m.move_cursor_to(m.spans[m.selected].node.start)
				return m.clone(), activate_editor(m.source_id)
			}
		}
		'q' {
			return m.clone(), close_editor2(m.id)
		}
		else {}
	}
	return m.clone(), tea.no_cmd
}

fn (mut m SyntaxTreeModel) select_row(row int) {
	if m.spans.len == 0 {
		m.selected = 0
		return
	}
	m.selected = row
	if m.selected < 0 {
		m.selected = 0
	}
	if m.selected >= m.spans.len {
		m.selected = m.spans.len - 1
	}
}

// move_cursor_to puts the document's cursor on `pos`, whose column counts
// runes where the cursor counts graphemes
fn (mut m SyntaxTreeModel) move_cursor_to(pos syntax.Pos) {
	runes := (m.doc_controller.get_line_bytes(m.doc_id, u64(pos.line)) or { []u8{} }).bytestr().runes()
	move_doc_cursor(m.doc_controller, m.doc_id, pos.line, graphemes_before_rune(runes, pos.col))
}

// sync brings the tree up to date with edits to the document
fn (mut m SyntaxTreeModel) sync() {
	changes := m.doc_controller.line_changes_since(m.doc_id, m.gen)
	m.gen = changes.gen
	if !changes.changed {
		return
	}
	if !changes.complete {
		m.tree.reset()
		return
	}
	m.tree.edited(changes.change.first, changes.change.last, changes.change.delta)
}

// refresh rebuilds the outline around the document's cursor: the nodes open
// a view's height above it, and those opening down to a view's height below
fn (mut m SyntaxTreeModel) refresh() {
	m.sync()
	line_count := int(m.doc_controller.line_count(m.doc_id))
	if line_count == 0 {
		m.spans = []
		m.cursor_row = -1
		return
	}
	cursor_line, cursor_x := m.doc_controller.cursor_line_and_x(m.doc_id)
	runes := (m.doc_controller.get_line_bytes(m.doc_id, cursor_line) or { []u8{} }).bytestr().runes()
	m.cursor_pos = syntax.Pos{int(cursor_line), rune_index_after_graphemes(runes, int(cursor_x))}

	reach := if m.height > 0 { m.height } else { 50 }
	first := if m.cursor_pos.line > reach { m.cursor_pos.line - reach } else { 0 }
	mut lines := DocLines{
		doc_id:         m.doc_id
		doc_controller: m.doc_controller
	}
	m.spans = m.tree.outline(mut m.parser, mut lines, first, m.cursor_pos.line + reach)
	m.labels = span_labels(m.spans, m.tree.definitions(mut m.parser, mut lines, first,
		m.cursor_pos.line + reach))
	m.cursor_scope = none
	if tok := m.tree.token_at(mut m.parser, mut lines, m.cursor_pos) {
		m.cursor_scope = tok.scope()
	}

	m.cursor_row = -1
	around := m.tree.ancestors(mut m.parser, mut lines, m.cursor_pos)
	if around.len > 0 {
		innermost := around.last()
		for i, span in m.spans {
			if span.node.start == innermost.start && span.node.depth == innermost.depth {
				m.cursor_row = i
				break
			}
		}
	}
	m.select_row(m.selected)
}

fn (mut m SyntaxTreeModel) view(mut ctx tea.Context) {
	m.refresh()
	if m.scope_colours.len == 0 {
		m.scope_colours = scope_colours(m.config.theme)
	}

	ctx.set_color(palette.subtle_text_fg_color)
	lang := if m.lang_syn.name.len > 0 { m.lang_syn.name } else { 'plain text' }
	ctx.draw_text(1, 0, 'syntax tree ${dot} ${lang} ${dot} ${os.base(m.file_path)}')
	scope_label := if scope := m.cursor_scope { '${scope}' } else { '-' }
	ctx.draw_text(1, 1, 'cursor [${m.cursor_pos.line}, ${m.cursor_pos.col}] ${dot} scope ${scope_label}')
	ctx.reset_color()

	rows := m.height - syntax_tree_header_rows
	if rows <= 0 {
		return
	}
	// keep the row that matters in view: the picked one while focused, the
	// cursor's node otherwise, or with the cursor outside every node, the
	// last node before it
	mut focus_row := if m.in_focus { m.selected } else { m.cursor_row }
	if focus_row < 0 {
		for i, span in m.spans {
			start := span.node.start
			if start.line > m.cursor_pos.line
				|| (start.line == m.cursor_pos.line && start.col > m.cursor_pos.col) {
				break
			}
			focus_row = i
		}
	}
	if focus_row >= 0 && focus_row < m.top_row {
		m.top_row = focus_row
	}
	if focus_row >= m.top_row + rows {
		m.top_row = focus_row - rows + 1
	}
	if m.top_row > m.spans.len - rows {
		m.top_row = if m.spans.len > rows { m.spans.len - rows } else { 0 }
	}

	if m.spans.len == 0 {
		ctx.set_color(palette.subtle_text_fg_color)
		ctx.draw_text(1, syntax_tree_header_rows, 'no nodes around the cursor')
		ctx.reset_color()
		return
	}

	end := if m.top_row + rows < m.spans.len { m.top_row + rows } else { m.spans.len }
	for row in m.top_row .. end {
		y := syntax_tree_header_rows + row - m.top_row
		if bg := m.row_bg_color(row) {
			ctx.set_bg_color(bg)
			ctx.draw_rect(0, y, m.width, 1)
			ctx.reset_bg_color()
		}

		span := m.spans[row]
		x := 1 + span.node.depth * 2
		colour := m.scope_colours[int(span.node.scope)]
		if colour.set {
			ctx.set_color(colour.colour)
		}
		label := m.labels[row]
		ctx.draw_text(x, y, label)
		if colour.set {
			ctx.reset_color()
		}
		ctx.set_color(palette.subtle_text_fg_color)
		ctx.draw_text(x + tea.visible_len(label) + 1, y, span_range_label(span))
		ctx.reset_color()
	}
}

// row_bg_color is the background of row `row`: the picked row's while
// focused, or the cursor's node's
fn (m SyntaxTreeModel) row_bg_color(row int) ?tea.Color {
	if m.in_focus && row == m.selected {
		return m.config.theme.highlight_bg_color
	}
	if row == m.cursor_row {
		return m.config.theme.cursor_line_bg
	}
	return none
}

// span_labels gives each span's row text: its node's name, followed for a
// context by the function or type it defines, e.g. `function main`: the first
// defined in it and not in a context within it. Each definition's context is
// found once, so it costs definitions times spans, not that times spans again.
fn span_labels(spans []syntax.Span, defs []syntax.Definition) []string {
	mut labels := spans.map(it.node.name)
	mut named := []bool{len: spans.len}
	for d in defs {
		if d.scope !in [.function_definition, .storage_type_definition] {
			continue
		}
		i := innermost_context(spans, d.pos) or { continue }
		if !named[i] {
			labels[i] = '${spans[i].node.name} ${d.name}'
			named[i] = true
		}
	}
	return labels
}

// innermost_context gives the index of the innermost context node among
// `spans` that `pos` is in
fn innermost_context(spans []syntax.Span, pos syntax.Pos) ?int {
	mut found := ?int(none)
	for i, span in spans {
		if span.node.kind == .context && span_contains(span, pos) {
			found = i
		}
	}
	return found
}

fn span_contains(span syntax.Span, pos syntax.Pos) bool {
	start := span.node.start
	if pos.line < start.line || (pos.line == start.line && pos.col < start.col) {
		return false
	}
	// `if` rather than `or`: the C backend misnames the option type of a
	// syntax.Pos unwrapped with `or` here, as bobatea has a Pos too
	if end := span.end {
		return pos.line < end.line || (pos.line == end.line && pos.col < end.col)
	}
	return true
}

// span_range_label is a span's range as [line, col] pairs counted from 0, the
// way Neovim's :InspectTree writes them, with … for an end not reached
fn span_range_label(span syntax.Span) string {
	start := '[${span.node.start.line}, ${span.node.start.col}]'
	if end := span.end {
		return '${start} - [${end.line}, ${end.col}]'
	}
	return '${start} - …'
}

fn (m SyntaxTreeModel) data() EditorData2 {
	cursor_line, cursor_x := m.doc_controller.cursor_line_and_x(m.doc_id)
	return EditorData2{
		id:         m.id
		file_path:  m.file_path
		cursor_row: int(cursor_line)
		cursor_col: int(cursor_x)
		width:      m.width
		height:     m.height
	}
}

fn (m SyntaxTreeModel) width() int {
	return m.width
}

fn (m SyntaxTreeModel) height() int {
	return m.height
}

fn (m SyntaxTreeModel) debug_data() DebugData {
	return DebugData{
		name: 'syntax tree view'
		data: {
			'id':        '${m.id}'
			'source_id': '${m.source_id}'
			'doc_id':    '${m.doc_id}'
			'nodes':     '${m.spans.len}'
		}
	}
}

fn (m SyntaxTreeModel) clone() tea.Model {
	return SyntaxTreeModel{
		...m
	}
}
