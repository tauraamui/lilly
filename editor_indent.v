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

import lib.syntax

// bracket_closers gives the rune that closes each bracket node
const bracket_closers = {
	'()': `)`
	'[]': `]`
	'{}': `}`
}

// NewLineIndent is the indentation for a line about to be opened at the
// cursor. With `closer` set, the cursor sits right before the bracket closing
// one opened on its own line, as in `{|}`: the bracket goes down a line
// further, indented by `closer`, leaving a line between for the cursor.
// `trim_before` and `trim_after` count the blanks either side of the cursor
// to take out first, as in `{ | }`, where they'd be left over at the end of
// the opener's line and before the closer.
struct NewLineIndent {
	indent      string
	closer      ?string
	trim_before int
	trim_after  int
}

// indent_unit is one level of indentation, as the config sets it
fn (m EditorModel) indent_unit() string {
	if m.config.convert_tabs_to_spaces {
		return ' '.repeat(if m.config.tab_width > 0 { m.config.tab_width } else { 4 })
	}
	return '\t'
}

// doc_line_runes gives line `y` of the document as it is in the buffer,
// without tabs expanded, so its columns are the context tree's
fn (m EditorModel) doc_line_runes(y int) []rune {
	line_bytes := m.doc_controller.get_line_bytes(m.doc_id, u64(y)) or { return []rune{} }
	return line_bytes.bytestr().runes()
}

// line_indent is the whitespace that line `y` starts with
fn (m EditorModel) line_indent(y int) string {
	runes := m.doc_line_runes(y)
	mut n := 0
	for n < runes.len && (runes[n] == ` ` || runes[n] == `\t`) {
		n++
	}
	return runes[..n].string()
}

// syntax_end_of gives the position just past `node`'s closing delimiter,
// looking no further than line `last`
fn (mut m EditorModel) syntax_end_of(node syntax.Node, last int) ?syntax.Pos {
	m.sync_parser_state_cache()
	mut lines := m.doc_lines()
	return m.syntax_tree.end_of(mut m.token_parser, mut lines, node, last - node.start.line)
}

// innermost_bracket gives the innermost bracket node open at `pos`, leaving
// out one opening right at it, since the cursor there is before it. It gives
// none inside a string or comment, where indentation is the writer's own.
fn (mut m EditorModel) innermost_bracket(pos syntax.Pos) ?syntax.Node {
	nodes := m.syntax_ancestors(pos).filter(it.start != pos)
	if nodes.len == 0 || nodes.last().scope in [.comment, .comment_doc, .string, .string_escape] {
		return none
	}
	for i := nodes.len - 1; i >= 0; i-- {
		if nodes[i].kind == .bracket {
			return nodes[i]
		}
	}
	return none
}

// new_line_indent works out how to indent a line opened at the cursor from
// the context tree: one level deeper than the line the bracket the cursor is
// in opened on, or level with it when the cursor is right before the
// bracket's closer. Outside any bracket, or with no syntax for the file, the
// line keeps the indentation of the one it is opened from.
fn (mut m EditorModel) new_line_indent() NewLineIndent {
	cursor_line, cursor_x := m.doc_controller.cursor_line_and_x(m.doc_id)
	y := int(cursor_line)
	fallback := NewLineIndent{
		indent: m.line_indent(y)
	}
	if m.lang_syn.name.len == 0 {
		return fallback
	}
	runes := m.doc_line_runes(y)
	col := rune_index_after_graphemes(runes, int(cursor_x))
	pos := syntax.Pos{y, col}
	bracket := m.innermost_bracket(pos) or { return fallback }
	base := m.line_indent(bracket.start.line)

	mut after := col
	for after < runes.len && runes[after] in [` `, `\t`] {
		after++
	}
	if m.closes_at(bracket, runes, y, after) {
		mut before := col
		for before > 0 && runes[before - 1] in [` `, `\t`] {
			before--
		}
		if bracket.start.line == y {
			return NewLineIndent{
				indent:      base + m.indent_unit()
				closer:      base
				trim_before: col - before
				trim_after:  after - col
			}
		}
		// opened on a line above, the blanks before the cursor may be all
		// this line has, its indent, so only those after it go
		return NewLineIndent{
			indent:     base
			trim_after: after - col
		}
	}
	return NewLineIndent{
		indent: base + m.indent_unit()
	}
}

// closes_at reports whether the rune at `col` of line `y`, whose runes are
// `runes`, is the closer that ends `bracket`
fn (mut m EditorModel) closes_at(bracket syntax.Node, runes []rune, y int, col int) bool {
	if col >= runes.len || runes[col] != bracket_closers[bracket.name] {
		return false
	}
	end := m.syntax_end_of(bracket, y) or { return false }
	return end == syntax.Pos{y, col + 1}
}

// open_line breaks the line at the cursor, indenting the new line by
// new_line_indent. Between a bracket and its closer it opens two, leaving the
// closer below and the cursor on the line between.
fn (mut m EditorModel) open_line() {
	nl := m.new_line_indent()
	for _ in 0 .. nl.trim_after {
		m.doc_controller.delete(m.doc_id)
	}
	for _ in 0 .. nl.trim_before {
		m.doc_controller.backspace(m.doc_id)
	}
	m.doc_controller.insert(m.doc_id, `\n`)
	m.doc_controller.insert_string(m.doc_id, nl.indent)
	if closer := nl.closer {
		m.doc_controller.insert(m.doc_id, `\n`)
		m.doc_controller.insert_string(m.doc_id, closer)
		m.doc_controller.move_cursor_up(m.doc_id)
		m.doc_controller.jump_cursor_to_line_end(m.doc_id)
	}
	m.insert_line_pristine_indent = nl.indent.len > 0
}

// align_closer re-indents the line the cursor is on, after a closing bracket
// was typed as the first thing on it, to the indentation of the line its
// bracket opened on
fn (mut m EditorModel) align_closer() {
	if m.lang_syn.name.len == 0 {
		return
	}
	cursor_line, cursor_x := m.doc_controller.cursor_line_and_x(m.doc_id)
	y := int(cursor_line)
	runes := m.doc_line_runes(y)
	col := rune_index_after_graphemes(runes, int(cursor_x)) - 1
	if col < 0 || runes[col] !in [`)`, `]`, `}`] {
		return
	}
	for r in runes[..col] {
		if r != ` ` && r != `\t` {
			return
		}
	}
	nodes := m.syntax_ancestors(syntax.Pos{y, col})
	if nodes.len == 0 {
		return
	}
	bracket := nodes.last()
	if bracket.kind != .bracket || bracket.start.line == y || !m.closes_at(bracket, runes, y, col) {
		return
	}
	indent := m.line_indent(bracket.start.line)
	if indent == runes[..col].string() {
		return
	}
	m.doc_controller.jump_cursor_to_line_start(m.doc_id)
	for _ in 0 .. col {
		m.doc_controller.delete(m.doc_id)
	}
	m.doc_controller.insert_string(m.doc_id, indent)
	m.doc_controller.move_cursor_right(m.doc_id)
}
