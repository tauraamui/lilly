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

// MemoryAccountable implementations for the screens that retain enough to be
// worth naming in the debug panel's memory view. A screen holding only scalars
// and a few short strings is left out: it would add rows without moving the
// unaccounted figure, and the point of the breakdown is to shrink that figure
// until what remains is garbage rather than mystery.
//
// Each implementation delegates to whatever it owns, so accounting the active
// screen walks the whole live screen tree from the top.

// footprint_bytes accounts the debug screen's own logs plus the screen beneath
// it, so opening the panel does not hide the thing being measured.
fn (m DebugScreenModel) footprint_bytes() u64 {
	wrapped := m.wrapped_model
	if wrapped is MemoryAccountable {
		return wrapped.footprint_bytes()
	}
	return 0
}

fn (m SplashScreenModel) footprint_bytes() u64 {
	// the logo is prepared once and is a fixed cost, but it is real, and
	// naming it keeps anyone from going looking for it again
	mut total := u64(0)
	for line in m.logo.lines {
		total += u64(line.runs.cap) * u64(sizeof(LogoRun))
		for run in line.runs {
			total += u64(run.text.len)
		}
	}
	if dialog := m.dialog_model {
		if dialog is MemoryAccountable {
			total += dialog.footprint_bytes()
		}
	}
	return total
}

// footprint_bytes accounts the three lists the picker keeps alive: every path
// the directory walk found, the filtered subset, and the preview of whatever
// is selected. The first grows with the size of the tree being browsed and is
// the one that matters.
fn (m FilePickerModel) footprint_bytes() u64 {
	mut total := string_array_footprint(m.finder.files())
	total += string_array_footprint(m.filtered_files)
	total += string_array_footprint(m.preview_lines)
	total += u64(m.preview_path.len) + u64(m.cached_cwd.len) + u64(m.last_filtered_query.len)
	return total
}

fn (m EditorWorkspaceModel2) footprint_bytes() u64 {
	mut total := u64(0)
	for _, editor in m.editors {
		if editor is MemoryAccountable {
			total += editor.footprint_bytes()
		}
	}
	if modal := m.active_modal {
		if modal is MemoryAccountable {
			total += modal.footprint_bytes()
		}
	}
	if dialog := m.dialog_model {
		if dialog is MemoryAccountable {
			total += dialog.footprint_bytes()
		}
	}
	return total
}

// footprint_bytes accounts the syntax highlighter's per-line state cache,
// which holds one entry per line of the open document and so scales with it.
fn (m EditorModel2) footprint_bytes() u64 {
	return u64(m.parser_line_states.cap) * u64(sizeof(syntax.State))
}
