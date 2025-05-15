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
import strconv
import lib.buffer
import lib.clipboardv2
import lib.workspace
import lib.draw
import lib.ui
import lib.core

@[heap]
struct Lilly {
	line_reader                       ?fn (file_path string) ![]string
	is_binary_file                    ?fn (file_path string) bool
mut:
	log                               log.Log
	clipboard                         clipboardv2.Clipboard
	view                              Viewable
	debug_view                        bool
	use_gap_buffer                    bool
	file_buffers                      map[string]buffer.Buffer
	buffer_views                      map[buffer.UUID_t]Viewable
	file_picker_modal                 ?ui.FilePickerModal
	inactive_buffer_picker_modal      ?ui.FilePickerModal
	todo_comments_picker_modal        ?ui.TodoCommentPickerModal
	workspace                         workspace.Workspace
	resolve_workspace_files           ?fn () []string
	syntaxes                          []workspace.Syntax
}

interface Root {
mut:
	open_file_picker(special_mode bool)
	open_inactive_buffer_picker(special_mode bool)
	open_todo_comments_picker()
	open_file(path string) !
	quit() !
	force_quit()
}

pub fn open_lilly(
	mut _log log.Log,
	cfg workspace.Config,
	mut _clipboard clipboardv2.Clipboard,
	commit_hash string, file_path string,
	workspace_root_dir string, use_gap_buffer bool,
) !&Lilly {
	mut lilly := Lilly{
		log: _log
		clipboard:         _clipboard
		use_gap_buffer: use_gap_buffer
		line_reader:    os.read_lines
	}
	lilly.workspace = workspace.open_workspace(mut _log, workspace_root_dir, os.is_dir,
		os.walk, cfg, os.config_dir, os.read_file, os.execute) or {
		return error("unable to open workspace '${workspace_root_dir}' -> ${err}")
	}
	lilly.resolve_workspace_files = lilly.workspace.get_files

	lilly.view = new_splash(commit_hash, lilly.workspace.config.leader_key)
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

fn (mut lilly Lilly) open_file(path string) ! {
	extracted_path, extracted_pos := extract_pos_from_path(path)
	return lilly.open_file_at(extracted_path, extracted_pos)
}

fn (mut lilly Lilly) open_file_at(path string, pos Pos) ! {
	return lilly.open_file_with_reader_at(path, pos, lilly.line_reader or { os.read_lines })
}

fn (mut lilly Lilly) open_file_with_reader_at(path string, pos Pos, line_reader fn (path string) ![]string) ! {
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

const colon = ":".runes()[0]

fn extract_pos_from_path(file_path string) (string, Pos) {
	mut pos := Pos{ x: -1, y: -1}

	mut from_index := file_path.len
	mut last_colon_index := 0
	for i := file_path.len - 1; i >= 0; i-- {
		c := file_path[i]
		if c != colon { continue }
		if from_index == file_path.len {
			pos_x_str := file_path[i + 1..from_index]
			pos.y = strconv.atoi(pos_x_str) or { 0 }
			from_index = i
			last_colon_index = i
			continue
		}

		if from_index < file_path.len {
			pos.x = pos.y
			pos_y_str := file_path[i + 1..from_index]
			pos.y = strconv.atoi(pos_y_str) or { 0 }
			last_colon_index = i
			break
		}
	}

	if pos.x == -1 { pos.x = 0 }
	if pos.y == -1 { pos.y = 0 }
	if last_colon_index == 0 { last_colon_index = file_path.len }

	return file_path[..last_colon_index], pos
}

fn (mut lilly Lilly) open_file_picker(special_mode bool) {
	if mut file_picker := lilly.file_picker_modal {
		if file_picker.is_open() { return } // this should never be reached
		file_picker.open()
		lilly.file_picker_modal = file_picker
		return
	}
	mut resolve_files := lilly.resolve_workspace_files or { lilly.workspace.get_files }
	mut file_picker := ui.FilePickerModal.new("", resolve_files(), special_mode)
	file_picker.open()
	lilly.file_picker_modal = file_picker
}

fn (mut lilly Lilly) close_file_picker() {
	mut file_picker := lilly.file_picker_modal or { return }
	file_picker.close()
	lilly.file_picker_modal = none
}

fn (mut lilly Lilly) open_inactive_buffer_picker(special_mode bool) {
	if mut inactive_buffer_picker := lilly.inactive_buffer_picker_modal {
		if inactive_buffer_picker.is_open() { return } // this should never happen/be reached
		inactive_buffer_picker.open()
		lilly.inactive_buffer_picker_modal = inactive_buffer_picker
		return
	}
	// TODO(tauraamui) [15/02/2025]: resolve all file paths for any buffers with no view instance
	//                               or any view which is not the current/active view
	mut inactive_buffer_picker := ui.FilePickerModal.new("INACTIVE BUFFERS PICKER", lilly.resolve_inactive_file_buffer_paths(), special_mode)
	inactive_buffer_picker.open()
	lilly.inactive_buffer_picker_modal = inactive_buffer_picker
}

fn (mut lilly Lilly) resolve_inactive_file_buffer_paths() []string {
	return lilly.buffer_views.values().filter(it != lilly.view).map(it.file_path)
}

fn (mut lilly Lilly) close_inactive_buffer_picker() {
	mut inactive_buffer_picker := lilly.inactive_buffer_picker_modal or { return }
	inactive_buffer_picker.close()
	lilly.inactive_buffer_picker_modal = none
}

fn (mut lilly Lilly) open_todo_comments_picker() {
	if mut todo_comments_picker := lilly.todo_comments_picker_modal {
		if todo_comments_picker.is_open() { return }
		todo_comments_picker.open()
		lilly.todo_comments_picker_modal = todo_comments_picker
		return
	}

	mut todo_comments_picker := ui.TodoCommentPickerModal.new(lilly.resolve_todo_comments_matches())
	todo_comments_picker.open()
	lilly.todo_comments_picker_modal = todo_comments_picker
}

// NOTE(tauraamui) [06/04/2025]: actually treesitter support might be unnecessary...
//                               for features which rely on language specific characteristics
//                               such as "is this string within a comment or not" should really be
//                               informed by something more sophisticated per language, so really
//                               we just need to add LSP support, since they normally use TS or whatever
//                               they want per language
//                               for basic stuff like syntax highlighting we can for now get away with just
//                               using a couple of handwritten parsers, since the new buffer arch requires
//                               an iterator traversing the full doc contents anyways, this is good enough now

// FIX(tauraamui) [02/03/2025]: should ensure that matches are within a comment block, ideally with treesitter
//                              but we don't have treesitter support yet, so unsure what to do for now but currently
//                              ironically due to all of the unit tests for this functionality we're getting a lot of
//                              false positive matches in the results list
fn (mut lilly Lilly) resolve_todo_comments_matches() []buffer.Match {
	mut matches := []buffer.Match{}
	match_ch    := chan buffer.Match{}
	mut threads := []thread{}

	mut matches_ref := &matches
	read_thread_ref := go read_matches_from_channel_write_to_array(mut matches_ref, match_ch)

	open_file_buffer_paths := lilly.file_buffers.keys()
	for file_path in open_file_buffer_paths {
		threads << go resolve_matches_within_buffer(lilly.file_buffers[file_path], match_ch)
	}

	resolve_workspace_files := lilly.resolve_workspace_files or { lilly.workspace.get_files }
	unopened_file_paths := resolve_workspace_files().filter(!open_file_buffer_paths.contains(it))
	line_reader := lilly.line_reader or { os.read_lines }
	is_binary   := lilly.is_binary_file or { core.is_binary_file }
	for file_path in unopened_file_paths {
		if is_binary(file_path) { continue }
		threads << go fn (line_reader fn (path string) ![]string, use_gap_buffer bool, file_path string, match_ch chan buffer.Match) {
			mut buff := buffer.Buffer.new(file_path, use_gap_buffer)
			buff.read_lines(line_reader) or { return }
			resolve_matches_within_buffer(buff, match_ch)
		}(line_reader, lilly.use_gap_buffer, file_path, match_ch)
	}

	threads.wait()
	match_ch.close()
	read_thread_ref.wait()

	return matches
}

fn read_matches_from_channel_write_to_array(mut matches []buffer.Match, match_ch chan buffer.Match) {
	for {
		m := <-match_ch or { break }
		matches << m
	}
}

fn resolve_matches_within_buffer(file_buffer buffer.Buffer, matches chan buffer.Match) {
	mut match_iter := file_buffer.match_iterator("TODO".runes())
	for !match_iter.done() {
		m_match := match_iter.next() or { continue }
		matches <- m_match
	}
}

fn (mut lilly Lilly) resolve_todo_comments_for_active_buffer(mut matches []buffer.Match) {
	file_path := lilly.view.file_path
	mut match_iter := lilly.file_buffers[file_path].match_iterator("TODO".runes())

	for !match_iter.done() {
		m_match := match_iter.next() or { continue }
		matches << m_match
	}
}

fn (mut lilly Lilly) resolve_todo_comments_across_workspace() []buffer.Match {
	mut matches := []buffer.Match{}

	return matches
}

fn (mut lilly Lilly) close_todo_comments_picker() {
	mut todo_comments_picker := lilly.todo_comments_picker_modal or { return }
	todo_comments_picker.close()
	lilly.todo_comments_picker_modal = none
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

	if mut todo_comments_picker := lilly.todo_comments_picker_modal {
		todo_comments_picker.draw(mut ctx)
		lilly.todo_comments_picker_modal = todo_comments_picker
		return
	}
}

pub fn (mut lilly Lilly) on_mouse_scroll(e draw.Event) {
	if e.direction == .unknown { return }
	lilly.view.on_mouse_scroll(e)
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
			lilly.inactive_buffer_picker_on_key_down(mut inactive_buffer_picker, e)
			return
		}
	}

	if mut todo_comments_picker := lilly.todo_comments_picker_modal {
		if todo_comments_picker.is_open() {
			lilly.todo_comments_picker_on_key_down(mut todo_comments_picker, e)
			return
		}
	}

	lilly.view.on_key_down(e, mut lilly)
}

// NOTE(tauraamui) [06/04/2025]: just tried reading the below comment again, lol wtf am I on about, I understand the premise
//                               but holy shit what a word salad

// TODO(tauraamui) [21/02/2025]: since these methods receive a concrete ref to the modal directly, rather than this logic
//                               being directly within the optional type unwrap scope where we're really modifying the result
//                               of the unwrap rather than the value/field on the struct that the optional was derived from, it might
//                               be the case that we can merge the two below methods relating to opening a file buffer in a view,
//                               if it's no longer necessary to re-assign the modified modal instance to it's corresponding struct field
//
//                               need to do some testing to be sure.
pub fn (mut lilly Lilly) file_picker_on_key_down(mut fp_modal ui.FilePickerModal, e draw.Event) {
	action := fp_modal.on_key_down(e)
	match action.op {
		.no_op { lilly.file_picker_modal = fp_modal }
		// NOTE(tauraamui) [12/02/2025]: should probably handle file opening failure better, will address in future (pinky promise!)
		.open_file_op {
			lilly.open_file(action.file_path) or { panic("failed to open file ${action.file_path}: ${err}") }
			lilly.close_file_picker()
			return
		}
		.close_op { lilly.close_file_picker(); return }
	}
}

pub fn (mut lilly Lilly) inactive_buffer_picker_on_key_down(mut inactive_buffer_picker ui.FilePickerModal, e draw.Event) {
	action := inactive_buffer_picker.on_key_down(e)
	match action.op {
		.no_op { lilly.inactive_buffer_picker_modal = inactive_buffer_picker }
		// NOTE(tauraamui) [16/02/2025]: should probably handle file opening failure better, will address in future (pinky promise!)
		.open_file_op {
			lilly.open_file(action.file_path) or { panic("failed to open file ${action.file_path}: ${err}") }
			lilly.close_inactive_buffer_picker()
			return
		}
		.close_op { lilly.close_inactive_buffer_picker(); return }
	}
}

pub fn (mut lilly Lilly) todo_comments_picker_on_key_down(mut todo_comments_picker ui.TodoCommentPickerModal, e draw.Event) {
	action := todo_comments_picker.on_key_down(e)
	match action.op {
		.no_op { lilly.todo_comments_picker_modal = todo_comments_picker }
		// NOTE(tauraamui) [16/02/2025]: should probably handle file opening failure better, will address in future (pinky promise!)
		.open_file_op {
			lilly.open_file(action.file_path) or { panic("failed to open file ${action.file_path}: ${err}") }
			lilly.close_todo_comments_picker()
			return
		}
		.close_op { lilly.close_todo_comments_picker(); return }
	}
}

// FIX(tauraamui) [06/04/2025]: dirty buffer tracking was broken at some point (sorry kelly!) when doing the partial migration
//                              to using the gap buffer instead of the existing buffer implementation
pub fn (mut lilly Lilly) quit() ! {
	mut dirty_count := 0
	for _, buff in lilly.file_buffers {
		if buff.dirty { dirty_count += 1 }
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
