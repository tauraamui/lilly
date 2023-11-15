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

struct Editor {
mut:
	view &Viewable = unsafe { nil }
	views []Viewable
}

pub fn open_editor(workspace_root_dir string) !&Editor {
	if !os.is_dir(workspace_root_dir) { return error("path ${workspace_root_dir} is not a directory") }
	mut editor := Editor{}
	editor.views << SplashScreen{}
	editor.view = &editor.views[0]
	return &editor
}

fn (mut editor Editor) open_file(path string) {
}

pub fn (mut editor Editor) draw(mut ctx tui.Context) {
	editor.view.draw(mut ctx)
}

pub fn (mut editor Editor) on_key_down(e &tui.Event) {
	editor.view.on_key_down(e)
}

