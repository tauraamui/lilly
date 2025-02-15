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
import lib.ui

@[heap]
struct Lilly {
mut:
	log                               log.Log
	clipboard                         clipboardv2.Clipboard
	view                              Viewable
	debug_view                        bool
	use_gap_buffer                    bool
	views                             []Viewable
	buffers                           []buffer.Buffer
	file_buffers                      map[string]buffer.Buffer
	buffer_views                      map[buffer.UUID_t]Viewable
	file_picker_modal                 ?ui.FilePickerModal
	inactive_buffer_picker_modal      ?ui.FilePickerModal
	inactive_buffer_finder_modal_open bool
	inactive_buffer_finder_modal      Viewable
	todo_comments_finder_modal_open   bool
	todo_comments_finder_modal        Viewable
	workspace                         workspace.Workspace
	syntaxes                          []workspace.Syntax
}

interface Root {
mut:
	open_file_picker(special_mode bool)
	open_inactive_buffer_picker(special_mode bool)
	open_todo_comments_finder()
	close_todo_comments_finder()
	open_file(path string) !
	quit() !
	force_quit()
}

pub fn open_lilly(
	mut _log log.Log,
	mut _clipboard clipboardv2.Clipboard,
	commit_hash string, file_path string,
	workspace_root_dir string, use_gap_buffer bool,
) !&Lilly {
	mut lilly := Lilly{
		log: _log
		clipboard:         _clipboard
		use_gap_buffer: use_gap_buffer
		inactive_buffer_finder_modal: unsafe { nil }
		todo_comments_finder_modal: unsafe { nil }
	}
	lilly.workspace = workspace.open_workspace(mut _log, workspace_root_dir, os.is_dir,
		os.walk, os.config_dir, os.read_file, os.execute) or {
		return error("unable to open workspace '${workspace_root_dir}' -> ${err}")
	}

	lilly.views << new_splash(commit_hash, lilly.workspace.config.leader_key)
	lilly.view = &lilly.views[0]
	if file_path.len != 0 {
		lilly.open_file(file_path)!
	}
	return &lilly
}

fn (mut lilly Lilly) start_debug() {
	lilly.debug_view = true
	lilly.view = &Debug{
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

fn (mut lilly Lilly) open_file_v2(path string) ! {
	return lilly.open_file_with_reader_v2(path, os.read_lines)
}

fn (mut lilly Lilly) open_file(path string) ! {
	return lilly.open_file_with_reader(path, os.read_lines)
}

fn (mut lilly Lilly) open_file_with_reader_v2(path string, line_reader fn (path string) ![]string) ! {
	defer {
		lilly.close_file_finder()
		lilly.close_inactive_buffer_finder()
	}

	if mut existing_file_buff := lilly.file_buffers[path] {
		if existing_view := lilly.buffer_views[existing_file_buff.uuid] {
			lilly.view = existing_view
			return
		}
		lilly.view = open_view(mut lilly.log, lilly.workspace.config, lilly.workspace.branch(),
					lilly.workspace.syntaxes(), lilly.clipboard, mut existing_file_buff)
		lilly.buffer_views[existing_file_buff.uuid] = lilly.view
		return
	}

	mut buff := buffer.Buffer.new(path, lilly.use_gap_buffer)
	buff.read_lines(line_reader) or { return err }

	lilly.file_buffers[path] = buff
	lilly.view = open_view(mut lilly.log, lilly.workspace.config, lilly.workspace.branch(),
				lilly.workspace.syntaxes(), lilly.clipboard, mut buff)
	lilly.buffer_views[buff.uuid] = lilly.view
}

fn (mut lilly Lilly) open_file_with_reader(path string, line_reader fn (path string) ![]string) ! {
	defer {
		lilly.close_file_finder()
		lilly.close_inactive_buffer_finder()
	}

	// find existing view which has that file open
	for i, view in lilly.views {
		if view.file_path == path {
			lilly.view = &lilly.views[i]
			return
		}
	}

	// couldn't find a view, so now search for an existing buffer with no view
	for i, buffer in lilly.buffers {
		if buffer.file_path == path {
			lilly.views << open_view(mut lilly.log, lilly.workspace.config, lilly.workspace.branch(),
				lilly.workspace.syntaxes(), lilly.clipboard, mut &lilly.buffers[i])
			lilly.view = &lilly.views[lilly.views.len - 1]
			return
		}
	}

	// neither existing view nor buffer was found, oh well, just load it then :)
	mut buff := buffer.Buffer.new(path, lilly.use_gap_buffer)
	buff.read_lines(line_reader) or { return err }
	lilly.buffers << buff
	lilly.views << open_view(mut lilly.log, lilly.workspace.config, lilly.workspace.branch(), lilly.workspace.syntaxes(),
		lilly.clipboard, mut &lilly.buffers[lilly.buffers.len - 1])
	lilly.view = &lilly.views[lilly.views.len - 1]
}

// disabled but not removed yet
// TODO(tauraamui) [14/02/2025]: remove this method at some point but not yet
/*
fn (mut lilly Lilly) open_file_finder(special_mode bool) {
	if lilly.inactive_buffer_finder_modal_open { return }
	lilly.file_finder_modal_open = true
	lilly.file_finder_modal = FileFinderModal{
		special_mode: special_mode
		log:    lilly.log
		title: "FILE BROWSER"
		file_path:  '**lff**'
		file_paths: lilly.workspace.files()
		close_fn: lilly.close_file_finder
	}
}
*/

fn (mut lilly Lilly) open_file_picker(special_mode bool) {
	if mut file_picker := lilly.file_picker_modal {
		if file_picker.is_open() { return } // this should never be reached
		file_picker.open()
		lilly.file_picker_modal = file_picker
		return
	}
	mut file_picker := ui.FilePickerModal.new("", lilly.workspace.files(), special_mode)
	file_picker.open()
	lilly.file_picker_modal = file_picker
}

fn (mut lilly Lilly) close_file_finder() {
	// lilly.file_finder_modal_open = false
}

fn (mut lilly Lilly) close_file_picker() {
	mut file_picker := lilly.file_picker_modal or { return }
	file_picker.close()
	lilly.file_picker_modal = none
}

// disabled but not removed yet
// TODO(tauraamui) [15/02/2025]: remove this method at some point but not yet
/*
fn (mut lilly Lilly) open_inactive_buffer_finder(special_mode bool) {
	// if lilly.file_finder_modal_open { return }
	lilly.inactive_buffer_finder_modal_open = true
	lilly.inactive_buffer_finder_modal = FileFinderModal{
		special_mode: special_mode
		log: lilly.log
		title: "INACTIVE BUFFERS"
		file_path:  '**lfb**'
		file_paths: lilly.views.filter(it != lilly.view && !it.file_path.starts_with("**")).map(it.file_path)
		close_fn: lilly.close_inactive_buffer_finder
	}
}
*/

fn (mut lilly Lilly) open_inactive_buffer_picker(special_mode bool) {
	if mut inactive_buffer_picker := lilly.inactive_buffer_picker_modal {
		if inactive_buffer_picker.is_open() { return } // this should never happen/be reached
		inactive_buffer_picker.open()
		lilly.inactive_buffer_picker_modal = inactive_buffer_picker
		return
	}
	// TODO(tauraamui) [15/02/2025]: resolve all file paths for any buffers with no view instance
	//                               or any view which is not the current/active view
	file_paths := []string{}
	mut inactive_buffer_picker := ui.FilePickerModal.new("INACTIVE BUFFERS PICKER", file_paths, special_mode)
	inactive_buffer_picker.open()
	lilly.inactive_buffer_picker_modal = inactive_buffer_picker
}

fn (mut lilly Lilly) close_inactive_buffer_finder() {
	// lilly.inactive_buffer_finder_modal_open = false
}

fn (mut lilly Lilly) close_inactive_buffer_picker() {
	mut inactive_buffer_picker := lilly.inactive_buffer_picker_modal or { return }
	inactive_buffer_picker.close()
	lilly.inactive_buffer_picker_modal = none
}

fn (mut lilly Lilly) open_todo_comments_finder() {
	defer { lilly.log.flush() }
	mut matches := []buffer.Match{}
	lilly.log.debug("searching ${lilly.buffers[0].file_path} for matches to 'TODO'")

	mut match_iter := lilly.buffers[0].match_iterator("TODO".runes())
	for !match_iter.done() {
		m_match := match_iter.next() or { continue }
		lilly.log.debug("found match: ${m_match.contents}")
		matches << m_match
	}

	if lilly.todo_comments_finder_modal_open { return }
	lilly.todo_comments_finder_modal_open = true
	lilly.todo_comments_finder_modal = TodoCommentFinderModal{
		log: lilly.log
		title: "TODO COMMENTS FINDER"
		file_path: "**tcf**"
		close_fn: lilly.close_todo_comments_finder
		matches: matches
	}
}

fn (mut lilly Lilly) close_todo_comments_finder() {
	lilly.todo_comments_finder_modal_open = false
}

pub fn (mut lilly Lilly) draw(mut ctx draw.Contextable) {
	lilly.view.draw(mut ctx)

	if mut file_picker := lilly.file_picker_modal {
		file_picker.draw(mut ctx)
		lilly.file_picker_modal = file_picker // draw internally can mutate state so ensure we keep this
		return
	}

	if mut inactive_buffer_picker := lilly.inactive_buffer_picker_modal {
		inactive_buffer_picker.draw(mut ctx)
		lilly.inactive_buffer_picker_modal = inactive_buffer_picker// draw internally can mutate state so ensure we keep this
		return
	}

	if lilly.todo_comments_finder_modal_open {
		lilly.todo_comments_finder_modal.draw(mut ctx)
		return
	}
}

pub fn (mut lilly Lilly) on_key_down(e draw.Event) {
	if mut file_picker := lilly.file_picker_modal {
		if file_picker.is_open() {
			lilly.file_picker_on_key_down(mut file_picker, e)
			return
		}
	}

	if mut inactive_buffer_picker := lilly.inactive_buffer_picker_modal {
		if inactive_buffer_picker.is_open() {
			lilly.file_picker_on_key_down(mut inactive_buffer_picker, e)
			return
		}
	}

	if lilly.todo_comments_finder_modal_open {
		lilly.todo_comments_finder_modal.on_key_down(e, mut lilly)
		return
	}

	lilly.view.on_key_down(e, mut lilly)
}

pub fn (mut lilly Lilly) file_picker_on_key_down(mut fp_modal ui.FilePickerModal, e draw.Event) {
	action := fp_modal.on_key_down(e)
	match action.op {
		.no_op { lilly.file_picker_modal = fp_modal }
		// NOTE(tauraamui) [12/02/2025]: should probably handle file opening failure better, will address in future (pinky promise!)
		.select_op {
			lilly.open_file(action.file_path) or { panic("failed to open file ${action.file_path}: ${err}") }
			lilly.close_file_picker()
			return
		}
		.close_op { lilly.close_file_picker(); return }
	}
}

pub fn (mut lilly Lilly) quit() ! {
	// Filter out splash/special views and check only file views
    file_views := lilly.views.filter(!it.file_path.starts_with('**'))
    mut dirty_count := 0
    for view in file_views {
        if view is View {
            if view.buffer.dirty {
                dirty_count++
            }
        }
    }

	if dirty_count > 0 {
		return error("Cannot quit: ${dirty_count} unsaved buffer(s). Save changes or use :q! to force quit")
	}
	lilly.view = unsafe { nil }
	exit(0)
}

pub fn (mut lilly Lilly) force_quit() {
    lilly.view = unsafe { nil }
    exit(0)
}
