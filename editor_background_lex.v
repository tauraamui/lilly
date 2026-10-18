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

// background_lex_budget is how long one editor's slice of background lexing
// may run before handing back to the update loop, which draws and handles
// any keys waiting before the next tick
const background_lex_budget = 4 * time.millisecond

// background_lex_idle_budget is a slice's budget while no key has come for
// background_lex_typing_window. The update loop runs once a frame, at 60 a
// second, and handles one tick each time, so slices of background_lex_budget
// lex for only a quarter of the time. With no keys to answer, a slice takes
// most of the frame instead, leaving the rest for drawing.
const background_lex_idle_budget = 12 * time.millisecond

// background_lex_typing_window is how long after a key slices keep to
// background_lex_budget, so typing stays answered within a frame or so
const background_lex_typing_window = 250 * time.millisecond

// background_lex_first_step is how many lines a slice lexes first. Each step
// after is sized from how long the one before took, to fill what's left of
// the budget, so long lines take fewer at a time and the slice still stops
// near its budget. Lines are lexed whole, so one huge line still overruns it.
const background_lex_first_step = 32

// background_lex_max_step caps a step, so a run of quick lines doesn't size
// one that a slow run after them would take far too long over
const background_lex_max_step = 4096

// background_lex_interval is the wait before the next slice. Any wait at all
// puts the next slice on a later turn of the update loop, so a frame can be
// drawn between slices; queued straight away, it would be handled in the same
// turn, and the whole document would lex before the first frame.
const background_lex_interval = time.millisecond

// BackgroundLexTickMsg asks every editor with lexing left to lex another
// slice in the background. The workspace keeps one on its way while any has
// lexing left. It carries nothing, so the tick that sends it needs no closure,
// as a closure would be kept forever, one per tick.
struct BackgroundLexTickMsg {}

fn background_lex_tick_msg(_ time.Time) tea.Msg {
	return BackgroundLexTickMsg{}
}

fn background_lex_tick() tea.Cmd {
	return tea.tick(background_lex_interval, background_lex_tick_msg)
}

// lex_pending reports whether the line start states or the context tree's
// checkpoints stop short of the end of the document, as they do on opening
// a file and below an edit that changed how the lines after it lex
fn (mut m EditorModel) lex_pending() bool {
	if m.lang_syn.name.len == 0 {
		return false
	}
	m.sync_parser_state_cache()
	line_count := int(m.doc_controller.line_count(m.doc_id))
	return m.parser_line_states.len < line_count || !m.syntax_tree.covers(line_count)
}

// background_lex lexes for up to `budget`: first the line start states,
// which drawing needs, then the tree's checkpoints, which queries do. Once
// both are done, jumping anywhere draws without lexing every line above it,
// and a query anywhere walks no more than a checkpoint's lines.
fn (mut m EditorModel) background_lex(budget time.Duration) {
	if !m.lex_pending() {
		return
	}
	line_count := int(m.doc_controller.line_count(m.doc_id))
	sw := time.new_stopwatch()
	mut step := background_lex_first_step
	for {
		started := sw.elapsed()
		if m.background_lex_step(step, line_count) {
			break
		}
		elapsed := sw.elapsed()
		if elapsed >= budget {
			break
		}
		step = next_background_lex_step(step, elapsed - started, budget - elapsed)
	}
}

// background_lex_step lexes `step` lines more: the line start states while
// they stop short of the end of the document's `line_count` lines, then the
// tree's checkpoints. It reports whether both are done.
fn (mut m EditorModel) background_lex_step(step int, line_count int) bool {
	if m.parser_line_states.len < line_count {
		target := m.parser_line_states.len - 1 + step
		m.ensure_parser_states(if target < line_count { target } else { line_count - 1 })
		return false
	}
	mut lines := m.doc_lines()
	return m.syntax_tree.warm(mut m.token_parser, mut lines, step)
}

// next_background_lex_step sizes the next step to fit `left`, at the pace of
// the last one, which took `took` over `step` lines
fn next_background_lex_step(step int, took time.Duration, left time.Duration) int {
	if took <= 0 {
		return if step * 2 < background_lex_max_step { step * 2 } else { background_lex_max_step }
	}
	next := i64(left) * step / i64(took)
	if next < 1 {
		return 1
	}
	if next > background_lex_max_step {
		return background_lex_max_step
	}
	return int(next)
}

// lex_slice_budget is the budget of a slice that comes `since_key` after the
// last key
fn lex_slice_budget(since_key time.Duration) time.Duration {
	return if since_key < background_lex_typing_window {
		background_lex_budget
	} else {
		background_lex_idle_budget
	}
}

// background_lex_update gives each editor with lexing left a slice, a short
// one while keys are coming
fn (mut m EditorWorkspaceModel) background_lex_update() {
	m.lex_ticking = false
	budget := lex_slice_budget(time.Duration(i64(time.sys_mono_now() - m.last_key_mono)))
	for id, editor in m.editors {
		if editor is EditorModel {
			mut e := EditorModel{
				...editor
			}
			e.background_lex(budget)
			m.editors[id] = e
		}
	}
}

// keep_lexing starts the tick that drives background lexing if an editor has
// lexing left and the tick isn't already on its way
fn (mut m EditorWorkspaceModel) keep_lexing() tea.Cmd {
	if m.lex_ticking {
		return tea.no_cmd
	}
	for id, editor in m.editors {
		if editor is EditorModel {
			mut e := EditorModel{
				...editor
			}
			pending := e.lex_pending()
			// syncing may have relexed, which the editor keeps
			m.editors[id] = e
			if pending {
				m.lex_ticking = true
				return background_lex_tick()
			}
		}
	}
	return tea.no_cmd
}
