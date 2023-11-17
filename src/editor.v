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
import lib.workspace

struct Editor {
mut:
	view      &Viewable = unsafe { nil }
	views     []Viewable
	buffers   []buffer.Buffer
	workspace workspace.Workspace
}

interface Root {
mut:
	open_file_finder()
	quit()
}

pub fn open_editor(workspace_root_dir string) !&Editor {
	mut editor := Editor{}
	editor.workspace = workspace.open_workspace(workspace_root_dir) or { return error("unable to open workspace '${workspace_root_dir}' -> ${err}") }
	editor.views << new_splash()
	editor.view = &editor.views[0]
	return &editor
}

fn (mut editor Editor) open_file(path string) ! {
	mut buff := buffer.Buffer{ file_path: path }
	buff.load_from_path() or { return err }
	editor.buffers << buff
}

fn (mut editor Editor) open_file_finder() {
}

pub fn (mut editor Editor) draw(mut ctx tui.Context) {
	editor.view.draw(mut ctx)
}

pub fn (mut editor Editor) on_key_down(e &tui.Event) {
	editor.view.on_key_down(e, mut editor)
}

pub fn (mut editor Editor) quit() {
	editor.view = unsafe { nil }
	exit(0)
}

