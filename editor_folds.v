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

// Folds are the syntax tree's blocks: each node that spans lines can be
// closed, so its first line stands for all of them. Which are closed belongs
// to the editor, as a window's folds do in Vim, so splits of one document
// fold apart. A closed fold keeps its lines, not its node: edits move it with
// the line change log, and one that reaches into it opens it.

// Fold is lines `start` to `end`, which show as line `start` alone while it's
// closed
struct Fold {
	start int
	end   int
}

fn (f Fold) contains(y int) bool {
	return f.start <= y && y <= f.end
}

fn (f Fold) encloses(other Fold) bool {
	return f.start <= other.start && other.end <= f.end && f != other
}

// after_edit gives where `f` is after an edit that changed lines `first` to
// `old_last`, as they were counted before it, and moved the lines below by
// `delta`. A fold around the edit grows or shrinks with it, and one the edit
// reaches into gives none, as it opens.
fn (f Fold) after_edit(first int, old_last int, delta int) ?Fold {
	if f.end < first {
		return f
	}
	if f.start > old_last {
		return Fold{f.start + delta, f.end + delta}
	}
	if f.start < first && f.end > old_last {
		return Fold{f.start, f.end + delta}
	}
	return none
}

// FoldReturn is where the cursor was, `line` and `x`, before a fold closed
// around it moved it to the fold's first line, so opening the fold puts it
// back, as Vim's cursor never leaves its line. It's forgotten once the cursor
// moves from where the close put it, `placed_line` and `placed_x`, or the
// document is edited, which `gen` dates.
struct FoldReturn {
	line        int
	x           int
	placed_line int
	placed_x    int
	gen         u64
}

// sorted_folds gives `folds` by start, outermost first, without repeats
fn sorted_folds(folds []Fold) []Fold {
	mut sorted := folds.clone()
	sorted.sort_with_compare(fn (a &Fold, b &Fold) int {
		if a.start != b.start {
			return if a.start < b.start { -1 } else { 1 }
		}
		if a.end != b.end {
			return if a.end > b.end { -1 } else { 1 }
		}
		return 0
	})
	mut unique := []Fold{cap: sorted.len}
	for f in sorted {
		if unique.len == 0 || unique.last() != f {
			unique << f
		}
	}
	return unique
}

// set_closed_folds closes `folds` and no others
fn (mut m EditorModel) set_closed_folds(folds []Fold) {
	closed := sorted_folds(folds)
	mut outer := []Fold{}
	for f in closed {
		if outer.len == 0 || f.start > outer.last().end {
			outer << f
		}
	}
	m.closed_folds = closed
	m.outer_folds = outer
}

// sync_folds brings the folds up to date with the edits made to the document
// since they were last synced, by any editor showing it, and after zM,
// closes the folds of the view and the cursor's line
fn (mut m EditorModel) sync_folds() {
	m.move_folds_with_edits()
	m.reach_view()
}

// move_folds_with_edits moves the closed folds, and the lines zM has reached,
// with the edits made since they were last synced. A fold around an edit
// grows or shrinks with it, and one an edit reaches into opens.
fn (mut m EditorModel) move_folds_with_edits() {
	changes := m.doc_controller.line_changes_since(m.doc_id, m.fold_gen)
	m.fold_gen = changes.gen
	if !changes.changed {
		return
	}
	if !changes.complete {
		m.folds_all = false
		m.fold_reach = []
		m.set_closed_folds([]Fold{})
		return
	}
	c := changes.change
	// the last line the edit changed, counted before it
	old_last := c.last - c.delta
	mut kept := []Fold{cap: m.closed_folds.len}
	for f in m.closed_folds {
		if moved := f.after_edit(c.first, old_last, c.delta) {
			kept << moved
		}
	}
	m.set_closed_folds(kept)
	mut reach := []LineRange{cap: m.fold_reach.len}
	for r in m.fold_reach {
		// the lines the edit changed stay in reach, so a fold being typed
		// doesn't close
		reach << LineRange{line_after_edit(r.first, c.first, old_last, c.first, c.delta), line_after_edit(r.last,
			c.first, old_last, c.last, c.delta)}
	}
	m.fold_reach = merged_ranges(reach)
}

// line_after_edit gives where line `y` is after an edit that changed lines
// `first` to `old_last`, as they were counted before it, and moved the lines
// below by `delta`. A line the edit changed goes to `changed`.
fn line_after_edit(y int, first int, old_last int, changed int, delta int) int {
	if y < first {
		return y
	}
	if y > old_last {
		return y + delta
	}
	return changed
}

// LineRange is lines `first` to `last`
struct LineRange {
	first int
	last  int
}

// merged_ranges gives `ranges` in order, with those that overlap or touch
// made one
fn merged_ranges(ranges []LineRange) []LineRange {
	mut sorted := ranges.clone()
	sorted.sort(a.first < b.first)
	mut merged := []LineRange{cap: sorted.len}
	for r in sorted {
		if merged.len == 0 || r.first > merged.last().last + 1 {
			merged << r
			continue
		}
		if r.last > merged.last().last {
			merged[merged.len - 1] = LineRange{merged.last().first, r.last}
		}
	}
	return merged
}

// gaps_in gives the lines from `first` to `last` that none of `ranges`, in
// order and apart, takes in
fn gaps_in(ranges []LineRange, first int, last int) []LineRange {
	mut gaps := []LineRange{}
	mut from := first
	for r in ranges {
		if r.last < from {
			continue
		}
		if r.first > last {
			break
		}
		if r.first > from {
			gaps << LineRange{from, r.first - 1}
		}
		from = r.last + 1
	}
	if from <= last {
		gaps << LineRange{from, last}
	}
	return gaps
}

// reach_folds, after zM, closes the folds of lines `first` to `last` that
// aren't in reach yet, and puts the lines in reach. A fold reaching lines
// already in reach was closed when they were, so it's left as it is: closed,
// or opened since. Lines hidden in a closed fold aren't reached until it
// opens, so a fold around the whole document doesn't cost all of it.
fn (mut m EditorModel) reach_folds(first int, last int) {
	if !m.folds_all {
		return
	}
	line_count := int(m.doc_controller.line_count(m.doc_id))
	from := if first > 0 { first } else { 0 }
	to := if last < line_count - 1 { last } else { line_count - 1 }
	gaps := m.unreached(from, to)
	if gaps.len == 0 {
		return
	}
	mut closed := m.closed_folds.clone()
	for gap in gaps {
		for f in m.folds_in(gap.first, gap.last) {
			if !m.fold_reach.any(f.start <= it.last && it.first <= f.end) {
				closed << f
			}
		}
	}
	mut reach := m.fold_reach.clone()
	reach << gaps
	m.fold_reach = merged_ranges(reach)
	m.set_closed_folds(closed)
}

// unreached gives the lines from `first` to `last` that are shown, but not
// in reach yet
fn (m EditorModel) unreached(first int, last int) []LineRange {
	mut shown := []LineRange{}
	for gap in gaps_in(m.fold_reach, first, last) {
		shown << m.shown_lines_of(gap)
	}
	return shown
}

// shown_lines_of gives the lines of `r` that aren't hidden in a closed fold
fn (m EditorModel) shown_lines_of(r LineRange) []LineRange {
	mut shown := []LineRange{}
	mut y := r.first
	if f := m.closed_fold_at(y) {
		if f.start < y {
			y = f.end + 1
		}
	}
	// the first closed fold starting at or below y
	mut i := m.outer_fold_from(y)
	for y <= r.last {
		if i >= m.outer_folds.len || m.outer_folds[i].start > r.last {
			shown << LineRange{y, r.last}
			break
		}
		f := m.outer_folds[i]
		// its first line shows
		shown << LineRange{y, f.start}
		y = f.end + 1
		i++
	}
	return shown
}

// outer_fold_from gives the index of the first of outer_folds that starts
// on line `y` or below it
fn (m EditorModel) outer_fold_from(y int) int {
	mut lo, mut hi := 0, m.outer_folds.len
	for lo < hi {
		mid := (lo + hi) / 2
		if m.outer_folds[mid].start < y {
			lo = mid + 1
			continue
		}
		hi = mid
	}
	return lo
}

// reach_rows, after zM, puts in reach the lines `rows` rows either side of
// line `y`'s, closing their folds first, so counting rows over them counts
// the folds zM closed as one each
fn (mut m EditorModel) reach_rows(y int, rows int) {
	if !m.folds_all {
		return
	}
	// a line past the end, as the top of a view whose lines an edit just
	// took, is counted from the last line: reach_folds reaches no further,
	// so lines past it would never be reached
	line_count := int(m.doc_controller.line_count(m.doc_id))
	from := if y < line_count { y } else { line_count - 1 }
	for {
		// closing folds can only take the rows further out, so this goes on
		// until every line they take in is in reach
		first := m.rows_up(from, rows)
		below := m.line_below(m.rows_down(from, rows))
		last := if below < line_count { below - 1 } else { line_count - 1 }
		if m.unreached(first, last).len == 0 {
			return
		}
		m.reach_folds(first, last)
	}
}

// reach_view, after zM, puts the cursor's line and a view's height either
// side of the top of the view in reach
fn (mut m EditorModel) reach_view() {
	if !m.folds_all {
		return
	}
	cursor_line, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
	m.reach_folds(int(cursor_line), int(cursor_line))
	m.reach_rows(m.top_line, m.viewport_height)
}

// closed_fold_at gives the outermost closed fold line `y` is in
fn (m EditorModel) closed_fold_at(y int) ?Fold {
	// the last outer fold starting at or above y
	mut lo, mut hi := 0, m.outer_folds.len
	for lo < hi {
		mid := (lo + hi) / 2
		if m.outer_folds[mid].start <= y {
			lo = mid + 1
			continue
		}
		hi = mid
	}
	if lo > 0 && m.outer_folds[lo - 1].contains(y) {
		return m.outer_folds[lo - 1]
	}
	return none
}

// shown_line gives the line that stands for line `y` on screen: the start of
// the closed fold it's in, or `y`
fn (m EditorModel) shown_line(y int) int {
	if f := m.closed_fold_at(y) {
		return f.start
	}
	return y
}

// line_below gives the first line below line `y`'s row: the line after the
// closed fold `y` starts, or after `y`
fn (m EditorModel) line_below(y int) int {
	if f := m.closed_fold_at(y) {
		return f.end + 1
	}
	return y + 1
}

// rows_down gives the line shown `rows` rows below line `y`'s, or the last
// line shown if there aren't that many
fn (m EditorModel) rows_down(y int, rows int) int {
	last := int(m.doc_controller.line_count(m.doc_id)) - 1
	if m.outer_folds.len == 0 {
		return if y + rows < last { y + rows } else { last }
	}
	mut line := m.shown_line(if y < last { y } else { last })
	for _ in 0 .. rows {
		next := m.line_below(line)
		if next > last {
			break
		}
		line = next
	}
	return line
}

// rows_up gives the line shown `rows` rows above line `y`'s, or the first
// line if there aren't that many
fn (m EditorModel) rows_up(y int, rows int) int {
	if m.outer_folds.len == 0 {
		return if y - rows > 0 { y - rows } else { 0 }
	}
	mut line := m.shown_line(y)
	for _ in 0 .. rows {
		if line == 0 {
			break
		}
		line = m.shown_line(line - 1)
	}
	return line
}

// fold_end gives the last line of the closed fold line `y` starts, or `y`
// when it starts none: the last line an action on line `y` takes in, as one
// on a closed fold acts on all of it
fn (mut m EditorModel) fold_end(y int) int {
	m.sync_folds()
	if f := m.closed_fold_at(y) {
		if f.start == y {
			return f.end
		}
	}
	return y
}

// screen_lines gives the line shown on each row of the view, top to bottom
fn (m EditorModel) screen_lines() []int {
	line_count := int(m.doc_controller.line_count(m.doc_id))
	mut rows := []int{cap: m.viewport_height}
	mut line := m.shown_line(m.top_line)
	for rows.len < m.viewport_height && line < line_count {
		rows << line
		line = m.line_below(line)
	}
	return rows
}

// screen_row gives the row of `rows` that shows line `y`, or none if it's
// off the view or hidden in a closed fold
fn screen_row(rows []int, y int) ?int {
	mut lo, mut hi := 0, rows.len
	for lo < hi {
		mid := (lo + hi) / 2
		if rows[mid] < y {
			lo = mid + 1
			continue
		}
		hi = mid
	}
	if lo < rows.len && rows[lo] == y {
		return lo
	}
	return none
}

// move_cursor_rows moves the cursor `n` rows down, or up for a negative `n`,
// stepping over each closed fold as one line, as j and k do
fn (mut m EditorModel) move_cursor_rows(n int) {
	m.sync_folds()
	cursor_line, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
	y := int(cursor_line)
	m.reach_rows(y, if n < 0 { -n } else { n })
	target := if n < 0 { m.rows_up(y, -n) } else { m.rows_down(y, n) }
	m.doc_controller.move_cursor_lines(m.doc_id, target - y)
}

// delete_rows deletes the lines from the cursor's to the one `n` rows down,
// or up for a negative `n`, as dj and dk do: whole lines, with all of a
// closed fold at either end. Like j and k, it does nothing if the cursor
// can't move.
fn (mut m EditorModel) delete_rows(n int) {
	m.sync_folds()
	cursor_line, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
	y := m.shown_line(int(cursor_line))
	m.reach_rows(y, if n < 0 { -n } else { n })
	target := if n < 0 { m.rows_up(y, -n) } else { m.rows_down(y, n) }
	if target == y {
		return
	}
	first := if target < y { target } else { y }
	last := m.fold_end(if target < y { y } else { target })
	for _ in first .. last + 1 {
		// each delete moves the next line up, into the line deleted
		m.doc_controller.delete_line(m.doc_id, u64(first))
	}
	m.doc_controller.commit_undo_group(m.doc_id)
	// the cursor goes to the line that moved up into the delete, or with
	// none, to the last line
	line_count := int(m.doc_controller.line_count(m.doc_id))
	mut to := first
	if to >= line_count {
		to = line_count - 1
	}
	m.doc_controller.jump_cursor_to_line(m.doc_id, u64(to))
	m.doc_controller.jump_cursor_to_text_start(m.doc_id)
}

// reveal_cursor opens the closed folds the cursor is hidden in, as Vim does
// on most moves into one. One starting on the cursor's line shows it, and
// stays closed.
fn (mut m EditorModel) reveal_cursor() {
	m.sync_folds()
	cursor_line, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
	y := int(cursor_line)
	f := m.closed_fold_at(y) or { return }
	if f.start == y {
		return
	}
	m.set_closed_folds(m.closed_folds.filter(!(it.start < y && y <= it.end)))
}

// settle_fold_cursor puts the cursor, which was at `x` on line `y` before a
// fold command, on the line that shows the one it was on before the folds
// closed around it: up to a closed fold's first line, or back to where it
// was when the fold it was hidden in opens
fn (mut m EditorModel) settle_fold_cursor(y int, x int) {
	mut from_line, mut from_x := y, x
	if r := m.fold_return {
		if r.gen == m.fold_gen && r.placed_line == y && r.placed_x == x {
			from_line, from_x = r.line, r.x
		}
	}
	m.fold_return = none
	shown := m.shown_line(from_line)
	if shown == from_line {
		if from_line != y || from_x != x {
			move_doc_cursor(m.doc_controller, m.doc_id, from_line, from_x)
		}
		return
	}
	m.doc_controller.move_cursor_lines(m.doc_id, shown - y)
	placed_line, placed_x := m.doc_controller.cursor_line_and_x(m.doc_id)
	m.fold_return = FoldReturn{
		line:        from_line
		x:           from_x
		placed_line: int(placed_line)
		placed_x:    int(placed_x)
		gen:         m.fold_gen
	}
}

// fold_command runs one of Vim's fold commands at the cursor:
//   zo opens the fold the cursor is on, zO it and every fold inside it
//   zc closes the innermost open fold around the cursor, zC every one
//   za and zA do zo and zO on a closed fold, zc and zC on an open one
//   zR opens every fold, zM closes every one
fn (mut m EditorModel) fold_command(command string) {
	m.sync_folds()
	cursor_line, cursor_x := m.doc_controller.cursor_line_and_x(m.doc_id)
	y := int(cursor_line)
	closed := m.closed_fold_at(y)
	match command {
		'zR' {
			m.folds_all = false
			m.fold_reach = []
			m.set_closed_folds([]Fold{})
		}
		'zM' {
			// every fold closes, ones opened before too, as lines come into
			// reach
			m.folds_all = true
			m.fold_reach = []
			m.set_closed_folds([]Fold{})
			m.reach_view()
		}
		'zo' {
			m.open_fold(closed, false)
		}
		'zO' {
			m.open_fold(closed, true)
		}
		'zc' {
			m.close_fold(y, closed, false)
		}
		'zC' {
			m.close_fold(y, closed, true)
		}
		'za' {
			m.toggle_fold(y, closed, false)
		}
		'zA' {
			m.toggle_fold(y, closed, true)
		}
		else {}
	}
	m.settle_fold_cursor(y, int(cursor_x))
}

// fold_command_visual runs a fold command over the rows of lines `first` to
// `last`, as Vim's do in visual mode: zo, zc and za act on each row as they
// would on it alone, zO and zC on every fold around each, and zR and zM as
// they do anywhere
fn (mut m EditorModel) fold_command_visual(command string, first int, last int) {
	if command in ['zR', 'zM'] {
		m.fold_command(command)
		return
	}
	m.sync_folds()
	m.reach_folds(first, last)
	end := m.fold_end(m.shown_line(last))
	around := m.folds_in(first, end)
	mut open := []Fold{}
	mut close := []Fold{}
	for y := m.shown_line(first); y <= end; y = m.line_below(y) {
		closed := m.closed_fold_at(y)
		mut opening := command in ['zo', 'zO']
		if command in ['za', 'zA'] {
			opening = closed != none
		}
		if !opening {
			close << innermost_to_close(around.filter(it.contains(y)), closed, command in [
				'zC',
				'zA',
			])
			continue
		}
		if f := closed {
			open << f
		}
	}
	mut folds := m.closed_folds.filter(it !in open)
	if command in ['zO', 'zA'] {
		// with each opened fold, the closed ones inside it
		for f in open {
			folds = folds.filter(!(f.start <= it.start && it.end <= f.end))
			m.reach_whole(f)
		}
	}
	folds << close
	m.set_closed_folds(folds)
	m.fold_return = none
	cursor_line, cursor_x := m.doc_controller.cursor_line_and_x(m.doc_id)
	m.settle_fold_cursor(int(cursor_line), int(cursor_x))
}

// fold_jump moves the cursor down to the start of the `count`th fold below
// it, as zj does, or with `up`, up to the end of the `count`th fold above
// it, as zk does. A closed fold counts as one fold, and the cursor stays
// put if there's none.
fn (mut m EditorModel) fold_jump(up bool, count int) {
	m.sync_folds()
	cursor_line, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
	start := int(cursor_line)
	mut y := start
	for _ in 0 .. count {
		// down, past the closed fold y starts, if it starts one
		row_end := m.line_below(y) - 1
		next := if up { m.fold_end_above(y) } else { m.fold_start_below(row_end) }
		if next < 0 {
			break
		}
		// after zM, the folds around it close first, as they would have
		m.reach_folds(next, next)
		y = m.shown_line(next)
	}
	m.doc_controller.move_cursor_lines(m.doc_id, y - start)
}

// fold_search_window is how many lines zj and zk look through first for
// the next fold, doubling the window each time they find none, so a search
// costs about as many lines as the fold is away, not the whole document
const fold_search_window = 64

// fold_start_below gives the first line below line `y` that a fold starts
// on, or -1 if there's none. A closed fold counts, even one whose block has
// changed since it closed.
fn (mut m EditorModel) fold_start_below(y int) int {
	line_count := int(m.doc_controller.line_count(m.doc_id))
	mut window := fold_search_window
	mut from := y + 1
	for from < line_count {
		to := if from + window < line_count { from + window - 1 } else { line_count - 1 }
		// a fold starting in the window is in it, and none started in the
		// lines searched before it
		mut folds := m.folds_in(from, to)
		folds << m.closed_folds
		found := first_start_below(folds, y)
		if found >= 0 && found <= to {
			return found
		}
		from = to + 1
		window *= 2
	}
	return -1
}

// fold_end_above gives the last line above line `y` that a fold ends on, or
// -1 if there's none. A closed fold counts, even one whose block has changed
// since it closed.
fn (mut m EditorModel) fold_end_above(y int) int {
	mut window := fold_search_window
	mut to := y - 1
	for to >= 0 {
		from := if to - window + 1 > 0 { to - window + 1 } else { 0 }
		// a fold ending in the window is in it, and none ended in the lines
		// searched before it
		mut folds := m.folds_in(from, to)
		folds << m.closed_folds
		found := last_end_above(folds, y)
		if found >= from {
			return found
		}
		to = from - 1
		window *= 2
	}
	return -1
}

// last_end_above gives the last line above line `y` that one of `folds`
// ends on, or -1 if there's none
fn last_end_above(folds []Fold, y int) int {
	mut found := -1
	for f in folds {
		if f.end < y && f.end > found {
			found = f.end
		}
	}
	return found
}

// first_start_below gives the first line below line `y` that one of
// `folds` starts on, or -1 if there's none
fn first_start_below(folds []Fold, y int) int {
	mut found := -1
	for f in folds {
		if f.start > y && (found < 0 || f.start < found) {
			found = f.start
		}
	}
	return found
}

// toggle_fold opens the closed fold on line `y`, `closed`, if there is one,
// as zo does, or else closes one around it, as zc does. With `nested`, it
// does zO or zC instead.
fn (mut m EditorModel) toggle_fold(y int, closed ?Fold, nested bool) {
	if _ := closed {
		m.open_fold(closed, nested)
		return
	}
	m.close_fold(y, closed, nested)
}

// open_fold opens `fold`, and with `nested` the closed folds inside it too
fn (mut m EditorModel) open_fold(fold ?Fold, nested bool) {
	f := fold or { return }
	if nested {
		m.set_closed_folds(m.closed_folds.filter(!(f.start <= it.start && it.end <= f.end)))
		m.reach_whole(f)
		return
	}
	m.set_closed_folds(m.closed_folds.filter(it != f))
}

// reach_whole, after zM, puts all of `f`'s lines in reach, for a fold opened
// with every fold inside it, which mustn't close as its lines come into view
fn (mut m EditorModel) reach_whole(f Fold) {
	if !m.folds_all {
		return
	}
	mut reach := m.fold_reach.clone()
	reach << LineRange{f.start, f.end}
	m.fold_reach = merged_ranges(reach)
}

// close_fold closes the innermost fold around line `y` that `closed`, the
// closed fold it's on, if any, is inside, or with `all` every fold around it
fn (mut m EditorModel) close_fold(y int, closed ?Fold, all bool) {
	mut folds := m.closed_folds.clone()
	folds << innermost_to_close(m.folds_at(y), closed, all)
	m.set_closed_folds(folds)
}

// innermost_to_close gives the fold of `around`, the folds around a line
// outermost first, that zc closes there: the innermost one that `closed`,
// the closed fold on the line, if any, is inside. With `all`, it gives every
// one, as zC closes.
fn innermost_to_close(around []Fold, closed ?Fold, all bool) []Fold {
	if all {
		return around
	}
	for i := around.len - 1; i >= 0; i-- {
		f := around[i]
		if c := closed {
			if !f.encloses(c) {
				continue
			}
		}
		return [f]
	}
	return []Fold{}
}

// folds_at gives the folds line `y` is in, outermost first
fn (mut m EditorModel) folds_at(y int) []Fold {
	return m.folds_in(y, y).filter(it.contains(y))
}

// folds_in gives the folds around line `first` and those starting on lines
// `first` to `last`, outermost first
fn (mut m EditorModel) folds_in(first int, last int) []Fold {
	m.sync_parser_state_cache()
	line_count := int(m.doc_controller.line_count(m.doc_id))
	mut lines := m.doc_lines()
	spans := m.syntax_tree.blocks(mut m.token_parser, mut lines, first, last)
	mut blocks := []syntax.Span{}
	for span in spans {
		if span.end != none {
			blocks << span
			continue
		}
		end := m.syntax_tree.end_of(mut m.token_parser, mut lines, span.node, line_count) or {
			continue
		}
		blocks << syntax.Span{
			node: span.node
			end:  end
		}
	}
	// what opens on the lines the blocks end on, which may end their folds
	// a line early. Those from `first` to `last` were found already, ones
	// that never end too, so only lines past them are walked again.
	mut openers := spans.filter(it.node.start.line >= first)
	mut seen := map[int]bool{}
	for span in blocks {
		// `if x := opt`, not `or`, which emits bad C for a Pos here
		if end := span.end {
			if end.line > last && end.line !in seen {
				seen[end.line] = true
				openers << m.syntax_tree.blocks(mut m.token_parser, mut lines, end.line,
					end.line).filter(it.node.start.line == end.line)
			}
		}
	}
	return sorted_folds(folds_of(blocks, openers))
}

// folds_of gives the folds of `blocks`. A fold runs from
// the line its block starts on to the line it ends on, or to the line above
// when one of `openers` starts after it there, so closing the first block of
// `} else {` leaves the line that opens the second showing. A block left one
// line long has no fold, and one that doesn't end has none.
fn folds_of(blocks []syntax.Span, openers []syntax.Span) []Fold {
	// the last column a block opens at on each line
	mut opens := map[int]int{}
	for span in openers {
		start := span.node.start
		last_col := opens[start.line] or { -1 }
		if start.col > last_col {
			opens[start.line] = start.col
		}
	}
	mut folds := []Fold{}
	for span in blocks {
		if end := span.end {
			opens_at := opens[end.line] or { -1 }
			last := if opens_at >= end.col { end.line - 1 } else { end.line }
			if last > span.node.start.line {
				folds << Fold{span.node.start.line, last}
			}
		}
	}
	return folds
}
