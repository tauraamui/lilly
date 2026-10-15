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
import lib.documents
import lib.documents.cursor
import lib.nanoid
import lib.palette
import lib.syntax

// BracketPair is where a bracket node's opener and closer are, each the
// position of the bracket rune itself
struct BracketPair {
	open  syntax.Pos
	close syntax.Pos
}

// bracket_pair_at gives the pair the bracket at `pos` belongs to, looking for
// an opener no further up than line `first` and a closer no further down than
// line `last`. Brackets in strings and comments, and ones without a match,
// have none.
fn (mut m EditorModel2) bracket_pair_at(pos syntax.Pos, first int, last int) ?BracketPair {
	if m.lang_syn.name.len == 0 {
		return m.counted_bracket_pair(pos, first, last)
	}
	runes := m.doc_line_runes(pos.line)
	if pos.col < 0 || pos.col >= runes.len {
		return none
	}
	r := runes[pos.col]
	if r !in [`(`, `[`, `{`, `)`, `]`, `}`] {
		return none
	}
	nodes := m.syntax_ancestors(pos)
	if nodes.len == 0 {
		return none
	}
	// the innermost node at an opener is the one it opens
	opened := nodes.last()
	if opened.start == pos {
		if opened.kind != .bracket {
			return none
		}
		end := m.syntax_end_of(opened, last) or { return none }
		// a bracket left open is closed by whatever closes what it's in, so
		// it only has a match if what closes it is its own closer
		close := syntax.Pos{end.line, end.col - 1}
		if m.rune_at(close) != bracket_closers[opened.name] {
			return none
		}
		return BracketPair{opened.start, close}
	}
	// a closer also closes any bracket left open inside its own, so its
	// own is the innermost of its kind, inside the context it's in
	for i := nodes.len - 1; i >= 0; i-- {
		node := nodes[i]
		if node.kind != .bracket {
			return none
		}
		if bracket_closers[node.name] != r {
			continue
		}
		// telling whether this closer is the opener's own walks the tree from
		// the opener down, as far as it's above
		if node.start.line < first {
			return none
		}
		end := m.syntax_end_of(node, pos.line) or { return none }
		if end != syntax.Pos{pos.line, pos.col + 1} {
			return none
		}
		return BracketPair{node.start, pos}
	}
	return none
}

// bracket_opens_of_kind and bracket_closes_of_kind are the brackets, each
// opener at the index of its closer
const bracket_opens_of_kind = [`(`, `[`, `{`]
const bracket_closes_of_kind = [`)`, `]`, `}`]

// counted_bracket_pair is bracket_pair_at for a file with no syntax, so no
// tree: as Vim does, it counts brackets of the bracket's kind, the way it
// faces, until one balances it
fn (m EditorModel2) counted_bracket_pair(pos syntax.Pos, first int, last int) ?BracketPair {
	r := m.rune_at(pos)
	opens := bracket_opens_of_kind.index(r)
	if opens >= 0 {
		closer := bracket_closes_of_kind[opens]
		mut depth := 0
		for y in pos.line .. last + 1 {
			runes := m.doc_line_runes(y)
			for col in (if y == pos.line { pos.col } else { 0 }) .. runes.len {
				if runes[col] == r {
					depth++
				}
				if runes[col] == closer {
					depth--
					if depth == 0 {
						return BracketPair{pos, syntax.Pos{y, col}}
					}
				}
			}
		}
		return none
	}
	closes := bracket_closes_of_kind.index(r)
	if closes >= 0 {
		opener := bracket_opens_of_kind[closes]
		mut depth := 0
		for y := pos.line; y >= first; y-- {
			runes := m.doc_line_runes(y)
			for col := if y == pos.line { pos.col } else { runes.len - 1 }; col >= 0; col-- {
				if runes[col] == r {
					depth++
				}
				if runes[col] == opener {
					depth--
					if depth == 0 {
						return BracketPair{syntax.Pos{y, col}, pos}
					}
				}
			}
		}
	}
	return none
}

fn (m EditorModel2) rune_at(pos syntax.Pos) rune {
	runes := m.doc_line_runes(pos.line)
	return if pos.col >= 0 && pos.col < runes.len { runes[pos.col] } else { 0 }
}

// cursor_pos is the cursor as a context tree position, in runes
fn (m EditorModel2) cursor_pos() syntax.Pos {
	cursor_line, cursor_x := m.doc_controller.cursor_line_and_x(m.doc_id)
	runes := m.doc_line_runes(int(cursor_line))
	return syntax.Pos{int(cursor_line), rune_index_after_graphemes(runes, int(cursor_x))}
}

// graphemes_before is how many graphemes come before rune `col` of line `y`,
// the cursor's column for that rune
fn (m EditorModel2) graphemes_before(y int, col int) int {
	return graphemes_before_rune(m.doc_line_runes(y), col)
}

// graphemes_before_rune is how many graphemes of `runes` come before rune `col`
fn graphemes_before_rune(runes []rune, col int) int {
	mut i := 0
	mut n := 0
	for i < col && i < runes.len {
		i = next_grapheme_rune_index(runes, i)
		n++
	}
	return n
}

fn (mut m EditorModel2) move_cursor_to_pos(pos syntax.Pos) {
	move_doc_cursor(m.doc_controller, m.doc_id, pos.line, m.graphemes_before(pos.line, pos.col))
}

// move_doc_cursor puts a document's cursor `x` graphemes into line `y`
fn move_doc_cursor(c &documents.Controller2, doc_id nanoid.ID, y int, x int) {
	c.jump_cursor_to_line(doc_id, u64(y))
	c.jump_cursor_to_line_start(doc_id)
	for _ in 0 .. x {
		c.move_cursor_right(doc_id)
	}
}

// matching_bracket gives the bracket pair `%` jumps across, as Vim finds it:
// the one under the cursor, or else the first after it on the line, with
// the position of the bracket to jump to. It gives none if the first is
// without a match.
fn (mut m EditorModel2) matching_bracket() ?(BracketPair, syntax.Pos) {
	pos := m.cursor_pos()
	runes := m.doc_line_runes(pos.line)
	last := int(m.doc_controller.line_count(m.doc_id)) - 1
	for col in pos.col .. runes.len {
		if runes[col] !in [`(`, `[`, `{`, `)`, `]`, `}`] {
			continue
		}
		at := syntax.Pos{pos.line, col}
		if pair := m.bracket_pair_at(at, 0, last) {
			return pair, if pair.open == at { pair.close } else { pair.open }
		}
		// past brackets in strings and comments, but not one without a match
		if !m.in_text(at) {
			return none
		}
	}
	return none
}

// in_text reports whether `pos` is in a string or comment
fn (mut m EditorModel2) in_text(pos syntax.Pos) bool {
	nodes := m.syntax_ancestors(pos)
	return nodes.len > 0 && nodes.last().kind == .context
		&& nodes.last().scope in [.comment, .comment_doc, .string, .string_escape]
}

// jump_to_matching_bracket is `%`: it moves the cursor onto the bracket
// matching the one under or after it, leaving it be with none to match
fn (mut m EditorModel2) jump_to_matching_bracket() {
	_, target := m.matching_bracket() or { return }
	m.move_cursor_to_pos(target)
}

// matching_bracket_range is what an operator with `%` acts on: from the
// cursor through the bracket matching the one under or after it, both
// brackets included, whichever way it goes
fn (mut m EditorModel2) matching_bracket_range() ?cursor.Range {
	_, target := m.matching_bracket()?
	from := m.cursor_pos()
	mut start, mut end := from, target
	if target.line < from.line || (target.line == from.line && target.col < from.col) {
		start, end = target, from
	}
	return cursor.Range{
		start: cursor.Pos.new(m.graphemes_before(start.line, start.col), start.line)
		end:   cursor.Pos.new(m.graphemes_before(end.line, end.col) + 1, end.line)
	}
}

// visible_bracket_pair is the pair to highlight: the one with a bracket
// under the cursor, or in insert mode just before it, as Neovim's matchparen
// does. As it does too, a pair is looked for only in the view: it's worked
// out on every frame, and a closer far below its opener costs a walk over
// every line between. `rows` are the lines the view shows, as screen_lines
// gives them.
fn (mut m EditorModel2) visible_bracket_pair(rows []int) ?BracketPair {
	if !m.in_focus || rows.len == 0 {
		return none
	}
	pos := m.cursor_pos()
	first := rows[0]
	last := rows.last()
	if pair := m.bracket_pair_at(pos, first, last) {
		return pair
	}
	if m.mode == .insert && pos.col > 0 {
		return m.bracket_pair_at(syntax.Pos{pos.line, pos.col - 1}, first, last)
	}
	return none
}

fn (mut m EditorModel2) render_matching_brackets(mut ctx tea.Context, rows []int) {
	pair := m.visible_bracket_pair(rows) or { return }
	ctx.set_bg_color(m.config.theme.highlight_bg_color)
	ctx.set_color(palette.fg_color(m.config.theme.highlight_bg_color))
	for pos in [pair.open, pair.close] {
		screen_y := screen_row(rows, pos.line) or { continue }
		x, width := m.visual_x_and_cluster_width_for(u64(pos.line), u64(m.graphemes_before(pos.line,
			pos.col)))
		ctx.draw_rect(x, screen_y, width, 1)
	}
	ctx.reset_color()
	ctx.reset_bg_color()
}
