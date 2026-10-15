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

module buffers

// line_change_log_cap bounds how many unread changes a buffer keeps. A reader
// that falls further behind than this is told to start over, which costs it
// one full pass rather than costing the buffer unbounded memory.
const line_change_log_cap = 256

// LineChange describes which lines an edit touched, so a reader holding
// per-line state (the syntax parser's line start states) can redo only those.
//
// Lines before `first` are untouched and keep their index. Lines from `first`
// to `last` inclusive, counted after the edit, are new or changed. Lines after
// `last` are untouched but have moved by `delta`: new line y was old line
// y - delta.
pub struct LineChange {
pub:
	first int
	last  int
	delta int
}

// then folds `next`, an edit applied after `c`, into one change covering both.
// The result can cover more lines than strictly changed, never fewer.
pub fn (c LineChange) then(next LineChange) LineChange {
	first := if c.first < next.first { c.first } else { next.first }
	// where c's last line ended up once next was applied: before next's
	// region it stays put, otherwise it moved with next or fell inside it
	mut last := c.last
	if c.last >= next.first {
		last = c.last + next.delta
	}
	if next.last > last {
		last = next.last
	}
	if last < first {
		last = first
	}
	return LineChange{
		first: first
		last:  last
		delta: c.delta + next.delta
	}
}

// LineChanges is what a reader gets back from line_changes_since.
pub struct LineChanges {
pub:
	// gen is the generation to pass to the next line_changes_since call
	gen u64
	// changed is false when nothing was edited since the reader's generation
	changed bool
	// complete is false when the reader fell behind the log, or has never
	// read it: its per-line state has to be rebuilt from scratch
	complete bool
	change   LineChange
}

struct LineChangeLog {
mut:
	entries []LineChange
	// dropped counts entries removed from the front, plus one so that
	// generation 0 is never current and can mean "never read"
	dropped u64 = 1
	// sealed is set whenever a reader looks at the log. Until then a new edit
	// is folded into the last entry instead of appending one, so a long run of
	// single-byte operations (delete_range, a paste) costs one entry.
	sealed bool = true
}

fn (log LineChangeLog) gen() u64 {
	return log.dropped + u64(log.entries.len)
}

fn (mut log LineChangeLog) add(change LineChange) {
	if !log.sealed && log.entries.len > 0 {
		last := log.entries.len - 1
		log.entries[last] = log.entries[last].then(change)
		return
	}
	if log.entries.len >= line_change_log_cap {
		log.entries.delete(0)
		log.dropped++
	}
	log.entries << change
	log.sealed = false
}

// since merges every change after generation `gen` into one. A gen of 0 is a
// reader that has never read the log, and always gets an incomplete result.
fn (mut log LineChangeLog) since(gen u64) LineChanges {
	log.sealed = true
	current := log.gen()
	if gen == 0 || gen < log.dropped || gen > current {
		return LineChanges{
			gen:      current
			changed:  true
			complete: false
		}
	}
	if gen == current {
		return LineChanges{
			gen:      current
			complete: true
		}
	}
	start := int(gen - log.dropped)
	mut merged := log.entries[start]
	for i in start + 1 .. log.entries.len {
		merged = merged.then(log.entries[i])
	}
	return LineChanges{
		gen:      current
		changed:  true
		complete: true
		change:   merged
	}
}

// line_changes_since reports which lines changed after generation `gen`.
// Readers start at 0, which always asks for a full rebuild.
pub fn (mut tb TextBuffer) line_changes_since(gen u64) LineChanges {
	return tb.line_changes.since(gen)
}
