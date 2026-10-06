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
import lib.boba
import lib.petal.theme

// A command that carries a message must be a tea.MsgCmd, never a tea.CmdFn.
//
// A CmdFn that captures anything is a closure, and V registers every closure's
// captured context in a process-wide table that nothing empties, so the
// context - and everything it transitively reaches - is pinned for the life of
// the process. These constructors run per keystroke and per editor action, so
// a closure here is an unbounded leak rather than a one-off cost. Measured on
// the closure form these replaced: 200k commands retained 39 MB; as MsgCmd the
// same 200k retain nothing.
//
// If this fails, a constructor has gone back to returning a closure. Build the
// message and hand it to tea.msg_cmd instead.
fn assert_carries_msg(name string, cmd tea.Cmd) {
	assert cmd !is tea.CmdFn, '${name} returns a closure; use tea.msg_cmd so its captures are not pinned forever'
	assert cmd is tea.MsgCmd, '${name} should deliver a message'
}

fn test_workspace_command_constructors_carry_messages() {
	assert_carries_msg('open_file', open_file('/tmp/a.txt'))
	assert_carries_msg('open_editor_workspace', open_editor_workspace('/tmp/a.txt'))
	assert_carries_msg('switch_mode', switch_mode(.insert))
	assert_carries_msg('run_command', run_command('w'))
	assert_carries_msg('focus_editor', focus_editor(1))
	assert_carries_msg('unfocus_editor', unfocus_editor(1))
	assert_carries_msg('switch_active_split', switch_active_split(.left))
}

fn test_editor_command_constructors_carry_messages() {
	assert_carries_msg('open_editor', open_editor('/tmp/a.txt'))
	assert_carries_msg('query_editor_data', query_editor_data(1))
	assert_carries_msg('editor_data', editor_data(EditorData{}))
	assert_carries_msg('write_to_disk', write_to_disk(1))
	assert_carries_msg('goto_line', goto_line(1, 12))
	assert_carries_msg('load_syntax', load_syntax(1, '/tmp/a.v'))
}

fn test_editor2_command_constructors_carry_messages() {
	assert_carries_msg('query_editor_data2', query_editor_data2('editor-1'))
	assert_carries_msg('editor_data2', editor_data2(EditorData2{}))
	assert_carries_msg('write_to_disk2', write_to_disk2('editor-1'))
	assert_carries_msg('load_syntax2', load_syntax2('editor-1', '/tmp/a.v'))
	assert_carries_msg('close_editor2', close_editor2('editor-1'))
	assert_carries_msg('focus_editor2', focus_editor2('editor-1'))
	assert_carries_msg('display_message', display_message(.normal, 'saved'))
	assert_carries_msg('git_branch_query_result', git_branch_query_result('master'))
	assert_carries_msg('resolve_unsaved_changes', resolve_unsaved_changes('editor-1', true,
		none))
	assert_carries_msg('open_editor_in_split_cmd', open_editor_in_split_cmd('editor-1',
		.vertical))
}

fn test_dialog_command_constructors_carry_messages() {
	assert_carries_msg('open_version_dialog', open_version_dialog('0.0.0', theme.dark_theme))
	assert_carries_msg('open_new_file_dialog', open_new_file_dialog(theme.dark_theme))
	assert_carries_msg('create_and_open_file', create_and_open_file('/tmp/a.txt'))
	assert_carries_msg('open_file_picker', open_file_picker(theme.dark_theme))
	assert_carries_msg('load_files', load_files('/tmp'))
	assert_carries_msg('filter_files_cmd', filter_files_cmd('a'))
	assert_carries_msg('debug_log', debug_log('hello'))
	assert_carries_msg('error_log', error_log('oh no'))
}

// The cursor re-arms about thirty times a second for as long as a field is
// focused, so this one matters more than the rest: it must be a plain TickCmd
// value, with a top-level function as its callback and nothing captured.
fn test_cursor_blink_rearms_without_a_closure() {
	cmd := boba.cursor_blink_cmd()
	assert cmd !is tea.CmdFn, 'the cursor blink must not re-arm through a closure'
	assert cmd is tea.TickCmd
}

// tea.batch and tea.sequence used to build a closure over their command array,
// so every batched update pinned the array and its members.
fn test_batch_and_sequence_do_not_build_closures() {
	pair := tea.batch(open_file('/tmp/a.txt'), write_to_disk(1))
	assert pair !is tea.CmdFn
	assert pair is tea.BatchCmd

	seq := tea.sequence(debug_log('a'), display_message(.normal, 'b'))
	assert seq !is tea.CmdFn
	assert seq is tea.SequenceCmd
}
