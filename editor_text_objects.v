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

import bobatea as tea
import lib.documents.cursor
import lib.syntax

// TextObject is what a text object such as `i{` or `a"` covers, from `start`
// up to, not including, `end`. A block's inside is `lines` when its brackets
// sit on lines of their own: it is then the whole lines between them,
// starting on the line after `open_line`.
struct TextObject {
	start     syntax.Pos
	end       syntax.Pos
	lines     bool
	open_line int
}

// is_text_object reports whether a chord's motion is a text object, which
// chords.v gives as `i` or `a` and the object's opening delimiter, e.g. `i(`
fn is_text_object(motion string) bool {
	return motion.len == 2 && motion[0] in [`i`, `a`]
}

// text_object finds the object `motion` names around the cursor. With a
// count, a block object is the count'th block of its kind out.
fn (mut m EditorModel) text_object(motion string, count int) ?TextObject {
	if m.lang_syn.name.len == 0 || !is_text_object(motion) {
		return none
	}
	inner := motion[0] == `i`
	return match motion[1] {
		`(` { m.block_object('()', inner, count) }
		`[` { m.block_object('[]', inner, count) }
		`{` { m.block_object('{}', inner, count) }
		`"`, `'`, `\`` { m.quote_object(rune(motion[1]), inner) }
		else { none }
	}
}

// block_object is `i(`, `a{` and the like: the count'th bracket node named
// `name` the cursor is in, from the innermost out, passing over brackets
// left open. `a` takes the brackets too; `i` takes what is between them, or
// with a bracket alone at the end or start of its line, leaves that line be.
fn (mut m EditorModel) block_object(name string, inner bool, count int) ?TextObject {
	pos := m.cursor_pos()
	last := int(m.doc_controller.line_count(m.doc_id)) - 1
	nodes := m.syntax_ancestors(pos)
	mut left := if count < 1 { 1 } else { count }
	for i := nodes.len - 1; i >= 0; i-- {
		node := nodes[i]
		if node.kind != .bracket || node.name != name {
			continue
		}
		end := m.syntax_end_of(node, last) or { continue }
		close := syntax.Pos{end.line, end.col - 1}
		if m.rune_at(close) != bracket_closers[name] {
			continue
		}
		left--
		if left > 0 {
			continue
		}
		if !inner {
			return TextObject{
				start: node.start
				end:   end
			}
		}
		return m.block_inside(node.start, close)
	}
	return none
}

// block_inside is what is between the bracket at `open` and its closer at
// `close`. A line break straight after the opener, or the indent before a
// closer starting its line, is left out, as Vim does.
fn (m EditorModel) block_inside(open syntax.Pos, close syntax.Pos) TextObject {
	mut start := syntax.Pos{open.line, open.col + 1}
	mut end := close
	opener_ends_line := start.col >= m.doc_line_runes(open.line).len
	// neither holds with both brackets on one line
	closer_starts_line := m.line_indent(close.line).runes().len == close.col
	if opener_ends_line && closer_starts_line {
		return TextObject{
			start:     syntax.Pos{open.line + 1, 0}
			end:       syntax.Pos{close.line, 0}
			lines:     true
			open_line: open.line
		}
	}
	if opener_ends_line {
		start = syntax.Pos{open.line + 1, 0}
	}
	if closer_starts_line {
		end = syntax.Pos{close.line - 1, m.doc_line_runes(close.line - 1).len}
	}
	return TextObject{
		start: start
		end:   end
	}
}

// QuotedSpan is a string literal: `start` is its first rune, a prefix such
// as V's `r` included, and its quotes run up to `inside_start` and from
// `inside_end` up to `end`
struct QuotedSpan {
	start        syntax.Pos
	inside_start syntax.Pos
	inside_end   syntax.Pos
	end          syntax.Pos
}

// quote_object is `i"`, `a'` and the like: the string the cursor is in that
// is quoted by `q`, or else the first after the cursor on its line. `i`
// takes what is between the quotes; `a` takes the whole string, prefix
// included, and the white space after it, or failing that, before it.
fn (mut m EditorModel) quote_object(q rune, inner bool) ?TextObject {
	pos := m.cursor_pos()
	span := m.quoted_span_at(pos, q) or { m.next_quoted_span(pos, q)? }
	if inner {
		return TextObject{
			start: span.inside_start
			end:   span.inside_end
		}
	}
	end_runes := m.doc_line_runes(span.end.line)
	mut after := span.end.col
	for after < end_runes.len && end_runes[after] in [` `, `\t`] {
		after++
	}
	if after > span.end.col {
		return TextObject{
			start: span.start
			end:   syntax.Pos{span.end.line, after}
		}
	}
	start_runes := m.doc_line_runes(span.start.line)
	mut before := span.start.col
	for before > 0 && start_runes[before - 1] in [` `, `\t`] {
		before--
	}
	// leave the indent of a string starting its line where it is
	if before == 0 {
		before = span.start.col
	}
	return TextObject{
		start: syntax.Pos{span.start.line, before}
		end:   span.end
	}
}

// quoted_span_at gives the innermost string quoted by `q` that `pos` is in:
// a node of the tree, from the innermost out, since only a string's are
// quoted at both ends, or else a string literal lexed as one token, as a
// rune literal is
fn (mut m EditorModel) quoted_span_at(pos syntax.Pos, q rune) ?QuotedSpan {
	last := int(m.doc_controller.line_count(m.doc_id)) - 1
	nodes := m.syntax_ancestors(pos)
	for i := nodes.len - 1; i >= 0; i-- {
		node := nodes[i]
		end := m.syntax_end_of(node, last) or { continue }
		if span := m.quoted_span(node.start, end, q) {
			return span
		}
	}
	tok := m.syntax_token_at(pos)?
	if tok.scope != .string {
		return none
	}
	return m.quoted_span(syntax.Pos{pos.line, tok.start()}, syntax.Pos{pos.line, tok.end()},
		q)
}

// next_quoted_span gives the first string quoted by `q` after `pos` on its
// line, for a `pos` in none
fn (mut m EditorModel) next_quoted_span(pos syntax.Pos, q rune) ?QuotedSpan {
	runes := m.doc_line_runes(pos.line)
	for col in pos.col + 1 .. runes.len {
		if runes[col] == q {
			return m.quoted_span_at(syntax.Pos{pos.line, col}, q) or { continue }
		}
	}
	return none
}

// quoted_span finds the quotes of the string from `start` up to `end`, if it
// is quoted by `q`: as many of them as both ends have, so `"""` quotes a
// Python docstring, after a prefix of a rune or two such as `r` or `b`
fn (m EditorModel) quoted_span(start syntax.Pos, end syntax.Pos, q rune) ?QuotedSpan {
	open_runes := m.doc_line_runes(start.line)
	mut first := start.col
	for first < open_runes.len && open_runes[first] != q && first - start.col < 2 {
		first++
	}
	if first >= open_runes.len || open_runes[first] != q {
		return none
	}
	one_line := start.line == end.line
	mut after := first
	for after < open_runes.len && open_runes[after] == q && (!one_line || after < end.col) {
		after++
	}
	close_runes := m.doc_line_runes(end.line)
	mut before := end.col
	for before > 0 && close_runes[before - 1] == q {
		before--
	}
	mut n := if after - first < end.col - before { after - first } else { end.col - before }
	// an empty string's quotes are one run: half open it, half close it
	if one_line && after == end.col {
		n = (end.col - first) / 2
	}
	if n == 0 {
		return none
	}
	return QuotedSpan{
		start:        start
		inside_start: syntax.Pos{start.line, first + n}
		inside_end:   syntax.Pos{end.line, end.col - n}
		end:          end
	}
}

// text_object_range is a text object as a range for an operator
fn (m EditorModel) text_object_range(obj TextObject) cursor.Range {
	return cursor.Range{
		start: cursor.Pos.new(m.graphemes_before(obj.start.line, obj.start.col), obj.start.line)
		end:   cursor.Pos.new(m.graphemes_before(obj.end.line, obj.end.col), obj.end.line)
	}
}

// apply_text_object applies `op` to the text object `motion`. Changing the
// inside of a block on lines of its own leaves one line open in it,
// indented as Enter would indent it. A change is undone in one go with what
// is typed after it.
fn (mut m EditorModel) apply_text_object(op u8, motion string, count int) (tea.Cmd, bool) {
	obj := m.text_object(motion, count) or { return tea.no_cmd, false }
	r := m.text_object_range(obj)
	match op {
		`d` {
			apply_operator(m.doc_controller, m.doc_id, op, r)
			m.doc_controller.commit_undo_group(m.doc_id)
			return tea.no_cmd, false
		}
		`c` {
			// begun here, undo puts the cursor back where the change was made
			m.doc_controller.begin_undo_group(m.doc_id)
			m.change_open = true
			// deleting an empty object, as in `ci(` on `()`, doesn't move the
			// cursor, which may be on the opener, so it's put inside first
			m.move_cursor_to_pos(obj.start)
			m.doc_controller.delete_range(m.doc_id, r)
			m.insert_line_pristine_indent = false
			if obj.lines {
				m.doc_controller.jump_cursor_to_line(m.doc_id, u64(obj.open_line))
				m.doc_controller.jump_cursor_to_line_end(m.doc_id)
				m.open_line()
			}
			// normal mode pulls a cursor at the end of the line back onto its
			// last rune, so in insert mode it has to step back out
			cursor_line, cursor_x := m.doc_controller.cursor_line_and_x(m.doc_id)
			if cursor_x == m.line_grapheme_count(int(cursor_line)) {
				return tea.sequence(switch_mode(.insert), virtual_direction_key_press('right')), true
			}
			return switch_mode(.insert), true
		}
		else {
			return tea.no_cmd, false
		}
	}
}

fn (m EditorModel) line_grapheme_count(y int) u64 {
	return u64(m.graphemes_before(y, m.doc_line_runes(y).len))
}

// select_text_object makes the visual selection the text object `motion`.
// A block is reached out from until it's more than the selection, so
// repeating `i{` grows the selection a block at a time, as in Vim.
fn (mut m EditorModel) select_text_object(motion string, count int) {
	mut n := if count < 1 { 1 } else { count }
	mut obj := m.text_object(motion, n) or { return }
	if motion[1] in [`(`, `[`, `{`] {
		for !m.grows_selection(obj) {
			n++
			obj = m.text_object(motion, n) or { return }
		}
	}
	if obj.end == obj.start {
		return
	}
	last_line, last_x := m.object_last(obj)
	m.visual_sel_start_line = u64(obj.start.line)
	m.visual_sel_start_col = u64(m.graphemes_before(obj.start.line, obj.start.col))
	move_doc_cursor(m.doc_controller, m.doc_id, last_line, last_x)
}

// object_last is where a selection of `obj` ends: a selection takes in the
// rune under the cursor, so on the last rune of the object, or the end of the
// line before an object ending at the start of one
fn (m EditorModel) object_last(obj TextObject) (int, int) {
	if obj.end.col == 0 {
		return obj.end.line - 1, int(m.line_grapheme_count(obj.end.line - 1)) - 1
	}
	return obj.end.line, m.graphemes_before(obj.end.line, obj.end.col) - 1
}

// grows_selection reports whether selecting `obj` takes in more than the
// visual selection does now. A selection of one rune, as visual mode starts
// with, is taken as none yet, as in Vim, so `i(` in `(a)` selects the `a`.
fn (mut m EditorModel) grows_selection(obj TextObject) bool {
	start_line := m.visual_sel_start_line or { return true }
	start_col := m.visual_sel_start_col or { return true }
	cursor_line, cursor_x := m.doc_controller.cursor_line_and_x(m.doc_id)
	if cursor_line == start_line && cursor_x == start_col {
		return true
	}
	if obj.end == obj.start {
		return false
	}
	// as (line, grapheme) pairs, the selection from `from` to `to`, whichever
	// way it was made, and the object's from first to last
	sel := [int(start_line), int(start_col)]
	cur := [int(cursor_line), int(cursor_x)]
	backwards := pos_before(cur, sel)
	from := if backwards { cur } else { sel }
	to := if backwards { sel } else { cur }
	first := [obj.start.line, m.graphemes_before(obj.start.line, obj.start.col)]
	last_line, last_x := m.object_last(obj)
	last := [last_line, last_x]
	holds := !pos_before(from, first) && !pos_before(last, to)
	return holds && (from != first || to != last)
}

fn pos_before(a []int, b []int) bool {
	return a[0] < b[0] || (a[0] == b[0] && a[1] < b[1])
}
