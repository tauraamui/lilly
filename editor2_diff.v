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
import lib.diff
import lib.nanoid

// default_diff_base_branches are tried in order when no base is given: the
// diff is taken against where the current branch left the first one found,
// so it shows everything pending on the branch, committed or not.
const default_diff_base_branches = ['master', 'main']

// InlineDiff is an editor's view of how its document differs from the same
// file at some git revision. Removed lines are drawn as extra rows between
// the document's own lines, so while it is enabled one document line no
// longer maps to one screen row: rows holds what each screen row shows.
struct InlineDiff {
mut:
	enabled bool
	// base_label names the revision the diff is against, for messages
	base_label string
	base_lines []string
	hunks      []diff.Hunk
	// revision is the document revision hunks were computed from
	revision u64
	computed bool
	// rows is the layout of the current frame, and line_rows[i] is the
	// screen row of document line top_line + i, or -1 when it is off screen
	rows      []DiffRow
	line_rows []int
}

enum DiffRowKind {
	line
	removed
}

// DiffRow is one screen row: a document line, or a line of the base that the
// document no longer has. index is the document line or the base line.
struct DiffRow {
	kind  DiffRowKind
	index int
	added bool
}

// diff_layout lays out height screen rows starting at document line top, with
// the first skip removed rows above top left out. Removed lines are placed
// above the document line that now follows where they were, and removed lines
// past the document's end after its last line.
fn diff_layout(hunks []diff.Hunk, top int, skip int, line_count int, height int, mut rows []DiffRow) {
	rows.clear()
	mut h := first_hunk_at_or_after(hunks, top)
	mut y := top
	for rows.len < height && y <= line_count {
		for h < hunks.len && hunks[h].new_start < y {
			h++
		}
		if h < hunks.len && hunks[h].new_start == y && hunks[h].old_count > 0 {
			hk := hunks[h]
			from := if y == top { skip } else { 0 }
			for i in from .. hk.old_count {
				if rows.len >= height {
					return
				}
				rows << DiffRow{
					kind:  .removed
					index: hk.old_start + i
				}
			}
		}
		if y == line_count || rows.len >= height {
			return
		}
		rows << DiffRow{
			kind:  .line
			index: y
			added: is_added_line(hunks, h, y)
		}
		y++
	}
}

// is_added_line reports whether document line y is new, given h, the first
// hunk that does not start before y
fn is_added_line(hunks []diff.Hunk, h int, y int) bool {
	if h < hunks.len && hunks[h].new_start == y && hunks[h].new_count > 0 {
		return true
	}
	if h > 0 {
		prev := hunks[h - 1]
		return y >= prev.new_start && y < prev.new_start + prev.new_count
	}
	return false
}

fn first_hunk_at_or_after(hunks []diff.Hunk, line int) int {
	mut lo, mut hi := 0, hunks.len
	for lo < hi {
		mid := (lo + hi) / 2
		if hunks[mid].new_start < line {
			lo = mid + 1
		} else {
			hi = mid
		}
	}
	return lo
}

// removed_rows_at is how many removed rows are drawn above document line y
fn removed_rows_at(hunks []diff.Hunk, y int) int {
	h := first_hunk_at_or_after(hunks, y)
	if h < hunks.len && hunks[h].new_start == y {
		return hunks[h].old_count
	}
	return 0
}

// diff_screen_row is the screen row of document line y, at or below top,
// counting the removed rows drawn between them
fn diff_screen_row(hunks []diff.Hunk, top int, skip int, y int) int {
	mut row := y - top - skip
	for h := first_hunk_at_or_after(hunks, top); h < hunks.len && hunks[h].new_start <= y; h++ {
		row += hunks[h].old_count
	}
	return row
}

fn (m EditorModel2) diff_active() bool {
	return m.diff.enabled && m.diff.computed
}

// refresh_diff recomputes the hunks when the document has changed since they
// were last computed
fn (mut m EditorModel2) refresh_diff() {
	if !m.diff.enabled {
		return
	}
	revision := m.doc_controller.revision(m.doc_id)
	if m.diff.computed && m.diff.revision == revision {
		return
	}
	line_count := int(m.doc_controller.line_count(m.doc_id))
	mut current := []string{cap: line_count}
	for y in 0 .. line_count {
		line_bytes := m.doc_controller.get_line_bytes(m.doc_id, u64(y)) or { []u8{} }
		current << line_bytes.bytestr()
	}
	m.diff.hunks = diff.lines(m.diff.base_lines, current)
	m.diff.revision = revision
	m.diff.computed = true
}

// scroll_to_cursor_with_diff is scroll_to_cursor for when removed rows sit
// between document lines: it scrolls a removed row at a time, so a block of
// removed lines taller than the editor can still be scrolled past.
fn (mut m EditorModel2) scroll_to_cursor_with_diff() {
	cursor_line_u, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
	cursor_line := int(cursor_line_u)
	line_count := int(m.doc_controller.line_count(m.doc_id))
	hunks := m.diff.hunks

	max_top := if line_count > m.viewport_height { line_count - m.viewport_height } else { 0 }
	if m.top_line > max_top {
		m.top_line = max_top
		m.top_removed_skip = 0
	}
	if cursor_line < m.top_line {
		m.top_line = cursor_line
		m.top_removed_skip = 0
	} else if cursor_line >= m.top_line + m.viewport_height {
		// skip the rows that can't be on screen without counting them
		m.top_line = cursor_line - m.viewport_height + 1
		m.top_removed_skip = 0
	}
	if m.top_line < 0 {
		m.top_line = 0
	}
	if m.top_removed_skip > removed_rows_at(hunks, m.top_line) {
		m.top_removed_skip = 0
	}
	if m.viewport_height <= 0 {
		return
	}
	for diff_screen_row(hunks, m.top_line, m.top_removed_skip, cursor_line) >= m.viewport_height {
		if m.top_removed_skip < removed_rows_at(hunks, m.top_line) {
			m.top_removed_skip++
		} else {
			m.top_line++
			m.top_removed_skip = 0
		}
	}
}

// layout_frame works out what each screen row shows for this frame
fn (mut m EditorModel2) layout_frame() {
	if !m.diff_active() {
		return
	}
	line_count := int(m.doc_controller.line_count(m.doc_id))
	diff_layout(m.diff.hunks, m.top_line, m.top_removed_skip, line_count, m.viewport_height, mut
		m.diff.rows)
	m.diff.line_rows.clear()
	for row, r in m.diff.rows {
		if r.kind == .line {
			for m.diff.line_rows.len < r.index - m.top_line {
				m.diff.line_rows << -1
			}
			m.diff.line_rows << row
		}
	}
}

// row_of is the screen row document line y is drawn on, or -1 when it is not
// on screen
fn (m EditorModel2) row_of(y int) int {
	if !m.diff_active() {
		row := y - m.top_line
		return if row >= 0 && row < m.viewport_height { row } else { -1 }
	}
	i := y - m.top_line
	if i < 0 || i >= m.diff.line_rows.len {
		return -1
	}
	return m.diff.line_rows[i]
}

// visible_line_end is one past the last document line on screen
fn (m EditorModel2) visible_line_end() int {
	if m.diff_active() {
		return m.top_line + m.diff.line_rows.len
	}
	line_count := int(m.doc_controller.line_count(m.doc_id))
	return if m.top_line + m.viewport_height < line_count {
		m.top_line + m.viewport_height
	} else {
		line_count
	}
}

// render_diff_backgrounds tints added lines and draws the removed ones, which
// take rows of their own
fn (m EditorModel2) render_diff_backgrounds(mut ctx tea.Context) {
	if !m.diff_active() {
		return
	}
	for row, r in m.diff.rows {
		match r.kind {
			.line {
				if r.added {
					ctx.set_bg_color(m.config.theme.diff_added_bg)
					ctx.draw_rect(0, row, m.viewport_width, 1)
					ctx.reset_bg_color()
				}
			}
			.removed {
				ctx.set_bg_color(m.config.theme.diff_removed_bg)
				ctx.draw_rect(0, row, m.viewport_width, 1)
				ctx.set_color(m.config.theme.syntax_comment)
				line := m.diff.base_lines[r.index] or { '' }
				ctx.draw_text(0, row, expand_tabs(line.bytes(), m.config.tab_width))
				ctx.reset_color()
				ctx.reset_bg_color()
			}
		}
	}
}

// render_diff_signs marks added and removed rows in the gutter column at x
fn (m EditorModel2) render_diff_signs(mut ctx tea.Context, x int) {
	if !m.diff_active() {
		return
	}
	for row, r in m.diff.rows {
		if r.kind == .removed {
			ctx.set_color(m.config.theme.petal_red)
			ctx.draw_text(x, row, '-')
			ctx.reset_color()
		} else if r.added {
			ctx.set_color(m.config.theme.petal_green)
			ctx.draw_text(x, row, '+')
			ctx.reset_color()
		}
	}
}

// ToggleInlineDiffMsg turns the inline diff on or off. With a base, it turns
// it on against that revision instead.
struct ToggleInlineDiffMsg {
	base string
}

fn toggle_inline_diff(editor_id nanoid.ID, base string) tea.Cmd {
	return tea.msg_cmd(EditorModel2Msg{
		active_id: editor_id
		msg:       ToggleInlineDiffMsg{
			base: base
		}
	})
}

fn (mut m EditorModel2) toggle_inline_diff_update(msg ToggleInlineDiffMsg) tea.Cmd {
	if m.diff.enabled && msg.base.len == 0 {
		m.diff = InlineDiff{}
		m.top_removed_skip = 0
		return display_message(.normal, 'diff off')
	}
	// git is run here, in the update, much as load_syntax2 resolves eagerly:
	// handing it to a thread would need a closure to carry the path back, and
	// closures are never released
	base := load_diff_base(m.file_path, msg.base, os.execute) or {
		return display_error_message('diff: ${err.msg()}')
	}
	m.diff = InlineDiff{
		enabled:    true
		base_label: base.label
		base_lines: base.lines
	}
	m.top_removed_skip = 0
	m.refresh_diff()
	return display_message(.normal, 'diff against ${base.label}: ${m.diff.hunks.len} hunks')
}

struct DiffBase {
	label string
	lines []string
}

// load_diff_base reads file_path as it was at base, or when base is empty, at
// the point the current branch left the first default branch found. A file
// git has no record of at that revision has an empty base: all of it is new.
fn load_diff_base(file_path string, base string, execute fn (cmd string) os.Result) !DiffBase {
	abs_path := os.real_path(file_path)
	dir := os.quoted_path(os.dir(abs_path))
	git := 'git -C ${dir}'

	mut rev := ''
	mut label := ''
	if base.len > 0 {
		res := execute('${git} rev-parse --verify --quiet ${os.quoted_path(base + '^{commit}')}')
		if res.exit_code != 0 {
			return error('unknown revision ${base}')
		}
		rev = res.output.trim_space()
		label = base
	} else {
		if execute('${git} rev-parse --verify --quiet HEAD').exit_code != 0 {
			return error('${os.file_name(file_path)} is not in a git repository with commits')
		}
		rev = 'HEAD'
		label = 'HEAD'
		for branch in default_diff_base_branches {
			res := execute('${git} merge-base HEAD ${branch}')
			if res.exit_code == 0 {
				rev = res.output.trim_space()
				label = '${branch} (${rev#[..8]})'
				break
			}
		}
	}

	name := os.quoted_path('${rev}:./${os.file_name(abs_path)}')
	res := execute('${git} show ${name}')
	if res.exit_code != 0 {
		return DiffBase{
			label: label
			lines: ['']
		}
	}
	return DiffBase{
		label: label
		lines: res.output.split('\n')
	}
}
