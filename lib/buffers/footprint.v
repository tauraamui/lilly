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

// Footprint is a breakdown of the heap a single buffer is sitting on. The
// numbers are derived from the live structures rather than sampled from the
// allocator, so they can be compared against gc_memory_use() to work out how
// much of the heap is buffer content and how much is garbage awaiting a sweep.
pub struct Footprint {
pub:
	// text_bytes is the gap buffer's backing store, gap included.
	text_bytes u64
	// line_index_bytes is the line offset index.
	line_index_bytes u64
	// history_bytes is the undo/redo payload: the bytes each recorded edit
	// carries, not the bookkeeping structs around them.
	history_bytes u64
	// history_groups is the number of recorded undo groups, which is the
	// figure to watch - history has no cap, so a long session only grows it.
	history_groups int
}

pub fn (f Footprint) total() u64 {
	return f.text_bytes + f.line_index_bytes + f.history_bytes
}

// +(a, b) sums two footprints, so a controller can fold over its documents.
pub fn (a Footprint) + (b Footprint) Footprint {
	return Footprint{
		text_bytes:       a.text_bytes + b.text_bytes
		line_index_bytes: a.line_index_bytes + b.line_index_bytes
		history_bytes:    a.history_bytes + b.history_bytes
		history_groups:   a.history_groups + b.history_groups
	}
}

pub fn (tb TextBuffer) footprint() Footprint {
	return Footprint{
		text_bytes:       tb.data_buf.footprint_bytes()
		line_index_bytes: tb.line_buf.footprint_bytes()
		history_bytes:    tb.history.footprint_bytes()
		history_groups:   tb.history.groups.len
	}
}

fn (h History) footprint_bytes() u64 {
	mut total := u64(0)
	for g in h.groups {
		total += g.footprint_bytes()
	}
	// the open group holds bytes too, and during a long insert run it is the
	// one actively growing
	total += h.cur.footprint_bytes()
	return total
}

fn (g UndoGroup2) footprint_bytes() u64 {
	mut total := u64(0)
	for op in g.ops {
		total += u64(op.bytes.cap)
	}
	return total
}

// footprint_bytes reports the heap held by the rune-based gap buffer backing
// the v1 document type.
pub fn (g GapBuffer) footprint_bytes() u64 {
	return u64(g.data.cap) * sizeof(rune)
}
