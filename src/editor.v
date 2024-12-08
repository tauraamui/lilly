// Copyright 2023 The Lilly Editor contributors
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
import log
import lib.buffer
import lib.clipboardv2
import lib.workspace
import lib.draw
@[heap]
struct Editor {
mut:
	log                               log.Log
	clipboard                         clipboardv2.Clipboard
	view                              &Viewable = unsafe { nil }
	debug_view                        bool
	use_gap_buffer                    bool
	views                             []Viewable
	buffers                           []buffer.Buffer
	file_finder_modal_open            bool
	file_finder_modal                 Viewable
	inactive_buffer_finder_modal_open bool
	inactive_buffer_finder_modal      Viewable
	workspace                         workspace.Workspace
	syntaxes                          []workspace.Syntax
}

interface Root {
mut:
	open_file_finder(special_mode bool)
	open_inactive_buffer_finder(special_mode bool)
	open_file(path string) !
	close_file_finder()
	quit()
}

pub fn open_editor(
	mut _log log.Log,
	mut _clipboard clipboardv2.Clipboard,
	commit_hash string, file_path string,
	workspace_root_dir string, use_gap_buffer bool,
) !&Editor {
	mut editor := Editor{
		log: _log
		clipboard:         _clipboard
		use_gap_buffer: use_gap_buffer
		file_finder_modal: unsafe { nil }
		inactive_buffer_finder_modal: unsafe { nil }
	}
	editor.workspace = workspace.open_workspace(mut _log, workspace_root_dir, os.is_dir,
		os.walk, os.config_dir, os.read_file) or {
		return error("unable to open workspace '${workspace_root_dir}' -> ${err}")
	}

	editor.views << new_splash(commit_hash, editor.workspace.config.leader_key)
	editor.view = &editor.views[0]
	if file_path.len != 0 {
		editor.open_file(file_path)!
	}
	return &editor
}

fn (mut editor Editor) start_debug() {
	editor.debug_view = true
	editor.view = &Debug{
		file_path: '**dbg**'
	}
}

fn is_binary_file(path string) bool {
    mut f := os.open(path) or { return false }
    mut buf := []u8{len: 1024}
    bytes_read := f.read_bytes_into(0, mut buf) or { return false }

    // Check first N bytes for binary patterns
    mut non_text_bytes := 0
    for i := 0; i < bytes_read; i++ {
        b := buf[i]
        // Count bytes outside printable ASCII range
        if (b < 32 && b != 9 && b != 10 && b != 13) || b > 126 {
            non_text_bytes++
        }
    }

    // If more than 30% non-text bytes, consider it binary
    return (f64(non_text_bytes) / f64(bytes_read)) > 0.3
}

fn (mut editor Editor) open_file(path string) ! {
	defer {
		editor.close_file_finder()
		editor.close_inactive_buffer_finder()
	}

	// find existing view which has that file open
	for i, view in editor.views[1..] {
		if view.file_path == path {
			editor.view = &editor.views[i + 1]
			return
		}
	}

	// couldn't find a view, so now search for an existing buffer with no view
	for i, buffer in editor.buffers {
		if buffer.file_path == path {
			editor.views << open_view(mut editor.log, editor.workspace.config, editor.workspace.branch(),
				editor.workspace.syntaxes(), editor.clipboard, mut &editor.buffers[i])
			editor.view = &editor.views[editor.views.len - 1]
			return
		}
	}

	// neither existing view nor buffer was found, oh well, just load it then :)
	mut buff := buffer.Buffer{
		file_path: path
	}
	buff.load_from_path(editor.use_gap_buffer) or { return err }
	editor.buffers << buff
	editor.views << open_view(mut editor.log, editor.workspace.config, editor.workspace.branch(), editor.workspace.syntaxes(),
		editor.clipboard, mut &editor.buffers[editor.buffers.len - 1])
	editor.view = &editor.views[editor.views.len - 1]
}

fn (mut editor Editor) open_file_finder(special_mode bool) {
	if editor.inactive_buffer_finder_modal_open { return }
	editor.file_finder_modal_open = true
	editor.file_finder_modal = FileFinderModal{
		special_mode: special_mode
		log:    editor.log
		title: "FILE BROWSER"
		file_path:  '**lff**'
		file_paths: editor.workspace.files()
		close_fn: editor.close_file_finder
	}
}

fn (mut editor Editor) close_file_finder() {
	editor.file_finder_modal_open = false
}

fn (mut editor Editor) open_inactive_buffer_finder(special_mode bool) {
	if editor.file_finder_modal_open { return }
	editor.inactive_buffer_finder_modal_open = true
	editor.inactive_buffer_finder_modal = FileFinderModal{
		special_mode: special_mode
		log: editor.log
		title: "INACTIVE BUFFERS"
		file_path:  '**lfb**'
		file_paths: editor.views.filter(it != editor.view && !it.file_path.starts_with("**")).map(it.file_path)
		close_fn: editor.close_inactive_buffer_finder
	}
}

fn (mut editor Editor) close_inactive_buffer_finder() {
	editor.inactive_buffer_finder_modal_open = false
}

pub fn (mut editor Editor) draw(mut ctx draw.Contextable) {
	editor.view.draw(mut ctx)

	if editor.file_finder_modal_open {
		editor.file_finder_modal.draw(mut ctx)
		return
	}

	if editor.inactive_buffer_finder_modal_open {
		editor.inactive_buffer_finder_modal.draw(mut ctx)
	}
}

pub fn (mut editor Editor) on_key_down(e draw.Event) {
	if editor.file_finder_modal_open {
		editor.file_finder_modal.on_key_down(e, mut editor)
		return
	}

	if editor.inactive_buffer_finder_modal_open {
		editor.inactive_buffer_finder_modal.on_key_down(e, mut editor)
		return
	}

	editor.view.on_key_down(e, mut editor)
}

pub fn (mut editor Editor) quit() {
	editor.view = unsafe { nil }
	exit(0)
}
