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
import lib.petal.theme

fn rune_key(s string) tea.KeyMsg {
	return tea.KeyMsg{
		k_type: .runes
		runes:  s.runes()
	}
}

fn special_key(name string) tea.KeyMsg {
	return tea.KeyMsg{
		k_type: .special
		runes:  name.runes()
	}
}

fn resolution_of(cmd fn () tea.Msg) ?ResolveUnsavedChangesMsg {
	// the dialog answers with a sequence: closing itself, then resolving. Only
	// the resolution carries the decision, so the sequence is walked for it.
	msg := cmd()
	if msg is tea.SequenceMsg {
		for c in []tea.Cmd(msg) {
			inner := c()
			if inner is ResolveUnsavedChangesMsg {
				return inner
			}
		}
	}
	if msg is ResolveUnsavedChangesMsg {
		return msg
	}
	return none
}

fn test_unsaved_changes_dialog_save_resolves_as_a_write() {
	mut m := UnsavedChangesDialogModel{
		theme:     theme.dark_theme
		editor_id: 'editor-1'
		file_path: '/tmp/notes.txt'
	}
	_, cmd := m.update(rune_key('s'))

	resolution := resolution_of(cmd) or {
		assert false, 'expected s to resolve the prompt'
		return
	}
	assert resolution.editor_id == 'editor-1'
	assert resolution.save
	assert resolution.then_open == none
}

fn test_unsaved_changes_dialog_discard_resolves_without_a_write() {
	mut m := UnsavedChangesDialogModel{
		theme:     theme.dark_theme
		editor_id: 'editor-1'
		file_path: '/tmp/notes.txt'
	}
	_, cmd := m.update(rune_key('d'))

	resolution := resolution_of(cmd) or {
		assert false, 'expected d to resolve the prompt'
		return
	}
	assert !resolution.save
}

fn test_unsaved_changes_dialog_carries_the_interrupted_open_through() {
	mut m := UnsavedChangesDialogModel{
		theme:     theme.dark_theme
		editor_id: 'editor-1'
		file_path: '/tmp/notes.txt'
		then_open: '/tmp/other.txt'
	}
	_, cmd := m.update(rune_key('s'))

	resolution := resolution_of(cmd) or {
		assert false, 'expected s to resolve the prompt'
		return
	}
	assert resolution.then_open? == '/tmp/other.txt'
}

fn test_unsaved_changes_dialog_cancel_only_closes_the_dialog() {
	mut m := UnsavedChangesDialogModel{
		theme:     theme.dark_theme
		editor_id: 'editor-1'
		file_path: '/tmp/notes.txt'
	}
	for key in [rune_key('c'), special_key('escape')] {
		_, cmd := m.update(key)
		assert resolution_of(cmd) == none, 'cancel must not resolve the prompt'
		assert cmd() is CloseDialogMsg
	}
}

fn test_unsaved_changes_dialog_ignores_unrelated_keys() {
	mut m := UnsavedChangesDialogModel{
		theme:     theme.dark_theme
		editor_id: 'editor-1'
		file_path: '/tmp/notes.txt'
	}
	_, cmd := m.update(rune_key('x'))
	assert cmd == tea.noop_cmd
}

fn test_truncate_to_width_leaves_a_line_that_fits_alone() {
	assert truncate_to_width('short', 20) == 'short'
	assert truncate_to_width('exactly ten', 11) == 'exactly ten'
}

fn test_truncate_to_width_clips_a_line_that_does_not_fit() {
	assert truncate_to_width('abcdefghij', 5) == 'abcd…'
	assert tea.visible_len(truncate_to_width('abcdefghij', 5)) == 5
	assert truncate_to_width('abcdefghij', 0) == ''
	assert truncate_to_width('abcdefghij', 1) == '…'
}
