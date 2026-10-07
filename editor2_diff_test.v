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

import os
import time
import lib.cfg
import lib.diff
import lib.documents
import lib.nanoid

fn layout_of(old []string, new []string, top int, skip int, height int) []DiffRow {
	mut rows := []DiffRow{}
	diff_layout(diff.lines(old, new), top, skip, new.len, height, mut rows)
	return rows
}

fn line_row(index int, added bool) DiffRow {
	return DiffRow{
		kind:  .line
		index: index
		added: added
	}
}

fn removed_row(index int) DiffRow {
	return DiffRow{
		kind:  .removed
		index: index
	}
}

fn test_diff_layout_puts_removed_lines_above_the_line_that_follows() {
	old := ['a', 'b', 'c', 'd']
	new := ['a', 'x', 'c', 'd', 'e']
	assert layout_of(old, new, 0, 0, 10) == [
		line_row(0, false),
		removed_row(1),
		line_row(1, true),
		line_row(2, false),
		line_row(3, false),
		line_row(4, true),
	]
}

fn test_diff_layout_puts_lines_removed_from_the_end_after_the_last_line() {
	assert layout_of(['a', 'b', 'c'], ['a'], 0, 0, 10) == [
		line_row(0, false),
		removed_row(1),
		removed_row(2),
	]
}

fn test_diff_layout_fills_only_the_height_and_honours_skip() {
	old := ['r0', 'r1', 'r2', 'keep', 'z']
	new := ['keep', 'z']
	assert layout_of(old, new, 0, 0, 2) == [removed_row(0), removed_row(1)]
	assert layout_of(old, new, 0, 2, 2) == [removed_row(2), line_row(0, false)]
	assert layout_of(old, new, 1, 0, 2) == [line_row(1, false)]
}

fn test_diff_screen_row_counts_removed_rows_between() {
	hunks := diff.lines(['a', 'gone', 'b', 'c'], ['a', 'b', 'c'])
	assert diff_screen_row(hunks, 0, 0, 0) == 0
	assert diff_screen_row(hunks, 0, 0, 1) == 2
	assert diff_screen_row(hunks, 0, 0, 2) == 3
	assert diff_screen_row(hunks, 1, 1, 1) == 0
}

fn make_diff_test_file(label string, content string) string {
	path := os.join_path(os.temp_dir(), 'lilly_diff_${label}_${time.now().unix_nano()}')
	os.write_file(path, content) or { panic('failed to write temp file: ${err}') }
	return path
}

fn editor_with_diff(c &documents.Controller2, doc_id nanoid.ID, base []string, height int) EditorModel2 {
	mut m := EditorModel2{
		config:          EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:          doc_id
		doc_controller:  c
		viewport_width:  40
		viewport_height: height
	}
	m.diff = InlineDiff{
		enabled:    true
		base_lines: base
	}
	m.refresh_diff()
	return m
}

fn test_scrolling_keeps_the_cursor_below_a_tall_removed_block_on_screen() {
	path := make_diff_test_file('tall', 'top\nkept\n')
	defer { os.rm(path) or {} }
	mut c := documents.Controller2{}
	doc_id := c.open_document(path) or { panic(err) }

	mut base := ['top']
	for i in 0 .. 10 {
		base << 'removed ${i}'
	}
	base << ['kept', '']
	mut m := editor_with_diff(&c, doc_id, base, 4)

	c.move_cursor_down(doc_id)
	m.scroll_to_cursor()
	m.layout_frame()
	row := m.row_of(1)
	assert row >= 0 && row < 4
	assert m.diff.rows.len == 4
	assert m.diff.rows[row] == line_row(1, false)
	assert m.diff.rows[row - 1] == removed_row(10)

	// back up to the first line shows it again, with nothing skipped
	c.move_cursor_up(doc_id)
	m.scroll_to_cursor()
	m.layout_frame()
	assert m.top_line == 0
	assert m.top_removed_skip == 0
	assert m.row_of(0) == 0
}

fn test_edits_recompute_the_diff() {
	path := make_diff_test_file('edits', 'one\ntwo\n')
	defer { os.rm(path) or {} }
	mut c := documents.Controller2{}
	doc_id := c.open_document(path) or { panic(err) }

	mut m := editor_with_diff(&c, doc_id, ['one', 'two', ''], 10)
	assert m.diff.hunks == []

	c.insert_rune(doc_id, `x`)
	m.refresh_diff()
	assert m.diff.hunks.len == 1
	assert m.diff.hunks[0].old_start == 0
	assert m.diff.hunks[0].new_count == 1
}

fn test_load_diff_base_reads_the_file_where_the_branch_left_master() {
	if os.execute('git --version').exit_code != 0 {
		eprintln('skipping: git is not installed')
		return
	}
	repo := os.join_path(os.temp_dir(), 'lilly_diff_repo_${time.now().unix_nano()}')
	os.mkdir_all(os.join_path(repo, 'sub')) or { panic(err) }
	defer { os.rmdir_all(repo) or {} }
	git := 'git -C ${os.quoted_path(repo)} -c user.name=t -c user.email=t@t -c commit.gpgsign=false'
	file := os.join_path(repo, 'sub', 'f.txt')

	assert os.execute('git init -q -b master ${os.quoted_path(repo)}').exit_code == 0
	os.write_file(file, 'base\nline\n')!
	assert os.execute('${git} add -A').exit_code == 0
	assert os.execute('${git} commit -q -m base').exit_code == 0
	assert os.execute('${git} switch -q -c feature').exit_code == 0
	os.write_file(file, 'branch\nline\n')!
	assert os.execute('${git} commit -q -am change').exit_code == 0
	os.write_file(file, 'working\nline\n')!

	base := load_diff_base(file, '', os.execute)!
	assert base.lines == ['base', 'line', '']
	assert base.label.starts_with('master (')

	head := load_diff_base(file, 'HEAD', os.execute)!
	assert head.lines == ['branch', 'line', '']

	new_file := os.join_path(repo, 'sub', 'new.txt')
	os.write_file(new_file, 'fresh\n')!
	assert load_diff_base(new_file, '', os.execute)!.lines == ['']

	if _ := load_diff_base(file, 'no-such-ref', os.execute) {
		assert false, 'expected an unknown revision to be an error'
	}
}
