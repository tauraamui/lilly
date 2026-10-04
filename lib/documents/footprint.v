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

module documents

import lib.buffers

// Footprint is a breakdown of the heap held by every document a controller has
// open. It walks the live structures, so it reports what is actually retained
// rather than what has been allocated over the session's lifetime.
pub struct Footprint {
pub:
	doc_count        int
	text_bytes       u64
	line_index_bytes u64
	history_bytes    u64
	history_groups   int
}

pub fn (f Footprint) total() u64 {
	return f.text_bytes + f.line_index_bytes + f.history_bytes
}

// footprint walks the v2 documents, whose content and undo history both live
// in the text buffer.
pub fn (c Controller2) footprint() Footprint {
	mut acc := buffers.Footprint{}
	for _, doc in c.docs {
		acc = acc + doc.footprint()
	}
	return Footprint{
		doc_count:        c.docs.len
		text_bytes:       acc.text_bytes
		line_index_bytes: acc.line_index_bytes
		history_bytes:    acc.history_bytes
		history_groups:   acc.history_groups
	}
}

// footprint walks the v1 documents, whose undo history is held by the
// controller alongside the document rather than inside it.
pub fn (c Controller) footprint() Footprint {
	mut text_bytes := u64(0)
	for _, doc in c.docs {
		text_bytes += doc.data.footprint_bytes()
	}
	mut history_bytes := u64(0)
	mut history_groups := 0
	for _, um in c.undo_managers {
		history_bytes += um.footprint_bytes()
		history_groups += um.undo_stack.len + um.redo_stack.len
	}
	return Footprint{
		doc_count:      c.docs.len
		text_bytes:     text_bytes
		history_bytes:  history_bytes
		history_groups: history_groups
	}
}

fn (um UndoManager) footprint_bytes() u64 {
	mut total := u64(0)
	for e in um.undo_stack {
		total += e.footprint_bytes()
	}
	for e in um.redo_stack {
		total += e.footprint_bytes()
	}
	total += u64(um.pending_content.cap) * sizeof(rune)
	return total
}

fn (e UndoEntry) footprint_bytes() u64 {
	return (u64(e.deleted.cap) + u64(e.inserted.cap)) * sizeof(rune)
}
