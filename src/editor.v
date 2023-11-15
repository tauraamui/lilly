module main

import os
import term.ui as tui

struct Editor {
mut:
	view &View = unsafe { nil }
	views []View
}

pub fn open_editor(workspace_root_dir string) !&Editor {
	if !os.is_dir(workspace_root_dir) { return error("path ${workspace_root_dir} is not a directory") }
	return error("editor not yet initable")
}

pub fn (mut editor Editor) draw(mut ctx tui.Context) {
	editor.view.draw(mut ctx)
}

pub fn (mut editor Editor) on_key_down(e &tui.Event) {
	editor.view.on_key_down(e)
}

