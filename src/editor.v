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
import term.ui as tui
import lib.buffer
import lib.clipboard
import lib.workspace
import lib.draw

struct Editor {
mut:
	clipboard              clipboard.Clipboard
	view                   &Viewable = unsafe { nil }
	views                  []Viewable
	buffers                []buffer.Buffer
	file_finder_modal_open bool
	file_finder_modal      Viewable
	workspace              workspace.Workspace
	syntaxes               []workspace.Syntax
}

interface Root {
mut:
	open_file_finder()
	open_file(path string) !
	close_file_finder()
	quit()
}

pub fn open_editor(_clipboard clipboard.Clipboard, workspace_root_dir string) !&Editor {
	mut editor := Editor{ clipboard: _clipboard, file_finder_modal: unsafe { nil } }
	editor.workspace = workspace.open_workspace(
			workspace_root_dir,
			os.is_dir,
			os.walk,
			os.config_dir,
			os.read_file
		) or { return error("unable to open workspace '${workspace_root_dir}' -> ${err}")
	}

	editor.views << new_splash(editor.workspace.config.leader_key)
	editor.view = &editor.views[0]
	return &editor
}

fn (mut editor Editor) open_file(path string) ! {
	defer { editor.file_finder_modal_open = false }

	// find existing view which has that file open
	for i, view in editor.views[1..] {
		if view.file_path == path {
			editor.view = &editor.views[i+1]
			return
		}
	}

	// couldn't find a view, so now search for an existing buffer with no view
	for i, buffer in editor.buffers {
		if buffer.file_path == path {
			editor.views << open_view(editor.workspace.config, editor.workspace.branch(), editor.workspace.syntaxes(), editor.clipboard, &editor.buffers[i])
			editor.view = &editor.views[editor.views.len-1]
			return
		}
	}

	// neither existing view nor buffer was found, oh well, just load it then :)
	mut buff := buffer.Buffer{ file_path: path }
	buff.load_from_path() or { return err }
	editor.buffers << buff
	editor.views << open_view(editor.workspace.config, editor.workspace.branch(), editor.workspace.syntaxes(), editor.clipboard, &editor.buffers[editor.buffers.len-1])
	editor.view = &editor.views[editor.views.len-1]
}

fn (mut editor Editor) open_file_finder() {
	editor.file_finder_modal_open = true
	editor.file_finder_modal = FileFinderModal{
		file_path: "**lff**"
		file_paths: editor.workspace.files()
	}
}

fn (mut editor Editor) close_file_finder() {
	editor.file_finder_modal_open = false
}

pub fn (mut editor Editor) draw(mut ctx draw.Contextable) {
  editor.view.draw(mut ctx)
	if editor.file_finder_modal_open {
		editor.file_finder_modal.draw(mut ctx)
	}
}

pub fn (mut editor Editor) on_key_down(e &tui.Event) {
	if editor.file_finder_modal_open {
		editor.file_finder_modal.on_key_down(e, mut editor)
		return
	}
	editor.view.on_key_down(e, mut editor)
}

pub fn (mut editor Editor) quit() {
	editor.view = unsafe { nil }
	exit(0)
}

