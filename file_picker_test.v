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
import lib.petal.theme
import bobatea as tea

struct MockFilesFinder {
mut:
	fake_files    []string = ['file1.txt', 'file2.txt', 'file3.txt']
	searched_path string
}

fn (f MockFilesFinder) files() []string {
	return f.fake_files
}

fn (mut f MockFilesFinder) search(root string) {
	f.searched_path = root
}

fn test_file_list_loads_files() {
	mut fp := FilePickerModel{
		theme:  theme.light_theme
		finder: MockFilesFinder{}
	}

	msg := LoadFilesMsg{
		root: './fake-root-dir'
	}
	m, _ := fp.update(msg)
	if m is FilePickerModel {
		fp = *m
	}

	assert fp.filtered_files.len == 3
}

fn test_clamp_file_list_to_scrolled() {
	initial_list := ['file1.txt', 'file2.txt', 'file3.txt', 'file4.txt', 'file5.txt', 'file6.txt',
		'file7.txt', 'file8.txt']
	assert clamp_files_list_to_scrolled(0, 100, initial_list) == initial_list
	assert clamp_files_list_to_scrolled(0, 5, initial_list) == ['file1.txt', 'file2.txt', 'file3.txt',
		'file4.txt', 'file5.txt']
	assert clamp_files_list_to_scrolled(1, 5, initial_list) == ['file2.txt', 'file3.txt', 'file4.txt',
		'file5.txt', 'file6.txt']
	assert clamp_files_list_to_scrolled(2, 5, initial_list) == ['file3.txt', 'file4.txt', 'file5.txt',
		'file6.txt', 'file7.txt']
	assert clamp_files_list_to_scrolled(3, 5, initial_list) == ['file4.txt', 'file5.txt', 'file6.txt',
		'file7.txt', 'file8.txt']
	assert clamp_files_list_to_scrolled(4, 5, initial_list) == ['file5.txt', 'file6.txt', 'file7.txt',
		'file8.txt']
	assert clamp_files_list_to_scrolled(5, 5, initial_list) == ['file6.txt', 'file7.txt', 'file8.txt']
	assert clamp_files_list_to_scrolled(6, 5, initial_list) == ['file7.txt', 'file8.txt']
	assert clamp_files_list_to_scrolled(7, 5, initial_list) == ['file8.txt']
}

fn write_preview_fixture(name string, content string) string {
	path := os.join_path(os.vtmp_dir(), 'lilly_preview_${os.getpid()}_${name}')
	os.write_file(path, content) or { panic(err) }
	return path
}

// picker_previewing returns a picker sized so its preview pane is rows by cols
// inside its border, with path selected
fn picker_previewing(path string, rows int, cols int) FilePickerModel {
	mut fp := FilePickerModel{
		theme:          theme.light_theme
		finder:         MockFilesFinder{}
		filtered_files: [path]
	}
	fp.resize_preview(rows, cols)
	return fp
}

fn (mut fp FilePickerModel) resize_preview(rows int, cols int) {
	// the inverse of preview_size, for an even width
	m, _ := fp.update(tea.ResizedMsg{
		window_width:  (cols + 2) * 2
		window_height: rows + 5
	})
	if m is FilePickerModel {
		fp = *m
	}
	got_rows, got_cols := fp.preview_size()
	assert got_rows == rows
	assert got_cols == cols
}

fn test_read_preview_lines_reads_only_what_was_asked_for() {
	path := write_preview_fixture('lines', 'one\ntwo\nthree\nfour\n')
	defer { os.rm(path) or {} }

	read := read_preview_lines(path, 0, 2, 80)
	assert read.lines == ['one', 'two']
	assert read.ends == [u64(4), 8]
	assert !read.done

	rest := read_preview_lines(path, read.ends.last(), 10, 80)
	assert rest.lines == ['three', 'four']
	assert rest.done
}

fn test_read_preview_lines_keeps_a_last_line_without_a_break() {
	path := write_preview_fixture('no_final_break', 'one\r\ntwo')
	defer { os.rm(path) or {} }

	read := read_preview_lines(path, 0, 10, 80)
	assert read.lines == ['one', 'two']
	assert read.done
}

fn test_read_preview_lines_cuts_lines_to_the_pane_width_like_the_renderer() {
	line := 'a\tb\x01 日本語 \u00e9\u00e9\u00e9 long tail that does not fit'
	path := write_preview_fixture('wide', '${line}\nshort\n')
	defer { os.rm(path) or {} }

	for cols in [1, 4, 5, 9, 12, 200] {
		read := read_preview_lines(path, 0, 10, cols)
		assert read.lines == [sanitize_preview_line(line, cols), sanitize_preview_line('short', cols)]
		assert read.cut == (cols < 200)
	}
}

fn test_read_preview_lines_stops_scanning_a_file_with_no_breaks() {
	path := write_preview_fixture('one_line', 'x'.repeat(max_preview_scan_bytes * 2))
	defer { os.rm(path) or {} }

	read := read_preview_lines(path, 0, 10, 8)
	assert read.lines == []
	assert read.done
}

fn test_preview_holds_only_the_lines_and_cells_the_pane_shows() {
	mut content := []string{}
	for i in 0 .. 1000 {
		content << 'line ${i} ' + 'x'.repeat(100)
	}
	path := write_preview_fixture('big', content.join('\n'))
	defer { os.rm(path) or {} }

	mut fp := picker_previewing(path, 10, 20)
	assert fp.preview_lines.len == 10
	assert fp.preview_lines[9] == content[9][..20]

	// taller: the new rows are read on from where the last read stopped
	fp.resize_preview(25, 20)
	assert fp.preview_lines.len == 25
	assert fp.preview_lines[24] == content[24][..20]

	// shorter and narrower: lines and cells no longer shown are dropped
	fp.resize_preview(5, 8)
	assert fp.preview_lines == content[..5].map(it[..8])

	// wider: the cut lines are read again to show more of them
	fp.resize_preview(5, 50)
	assert fp.preview_lines == content[..5].map(it[..50])

	// taller again after a shrink resumes after the last kept line
	fp.resize_preview(7, 50)
	assert fp.preview_lines == content[..7].map(it[..50])
}

fn test_preview_of_a_short_file_stops_at_its_end() {
	path := write_preview_fixture('short', 'one\ntwo\n')
	defer { os.rm(path) or {} }

	mut fp := picker_previewing(path, 10, 20)
	assert fp.preview_lines == ['one', 'two']
	assert fp.preview_done

	fp.resize_preview(30, 40)
	assert fp.preview_lines == ['one', 'two']
}

fn test_selecting_another_file_previews_it_from_its_start() {
	long := write_preview_fixture('select_long', 'first ${'a'.repeat(50)}\nsecond\nthird\n')
	defer { os.rm(long) or {} }
	short := write_preview_fixture('select_short', 'one\ntwo\n')
	defer { os.rm(short) or {} }

	mut fp := picker_previewing(long, 2, 10)
	fp.filtered_files = [long, short]
	assert fp.preview_lines == ['first aaaa', 'second']
	assert fp.preview_cut
	assert !fp.preview_done

	// nothing of the first file's preview carries over: its cut lines, where
	// its reading stopped, or that it had more to read
	fp.selected_index = 1
	fp.load_preview()
	assert fp.preview_path == short
	assert fp.preview_lines == ['one', 'two']
	assert fp.preview_ends == [u64(4), 8]
	assert !fp.preview_cut

	fp.selected_index = 0
	fp.load_preview()
	assert fp.preview_path == long
	assert fp.preview_lines == ['first aaaa', 'second']
	assert fp.preview_cut
}

fn test_preview_is_cleared_when_nothing_is_selected() {
	path := write_preview_fixture('cleared', 'one\ntwo\n')
	defer { os.rm(path) or {} }

	mut fp := picker_previewing(path, 10, 20)
	assert fp.preview_lines == ['one', 'two']

	fp.filtered_files = []
	fp.load_preview()
	assert fp.preview_path == ''
	assert fp.preview_lines == []
	assert fp.preview_ends == []
	assert fp.preview_done

	// an index left past the end of a shorter list selects nothing either
	fp.filtered_files = [path]
	fp.selected_index = 3
	fp.load_preview()
	assert fp.preview_path == ''
	assert fp.preview_lines == []
}

// load_preview runs on every message the picker gets, so a message that
// leaves the pane's size alone must leave the preview alone too, rather than
// rebuilding the same lines on every keypress
fn test_a_same_size_update_keeps_the_preview_as_it_is() {
	mut content := []string{}
	for i in 0 .. 20 {
		content << 'line ${i} ' + 'x'.repeat(30)
	}
	path := write_preview_fixture('same_size', content.join('\n'))
	defer { os.rm(path) or {} }

	mut fp := picker_previewing(path, 10, 20)
	lines_before := fp.preview_lines.data
	ends_before := fp.preview_ends.data

	fp.resize_preview(10, 20)
	fp.load_preview()
	assert fp.preview_lines == content[..10].map(it[..20])
	assert fp.preview_lines.data == lines_before
	assert fp.preview_ends.data == ends_before
}

fn cells_of(line string) int {
	mut cells := 0
	for r in line.runes() {
		cells += rune_cells(r)
	}
	return cells
}

fn test_preview_lines_with_wide_runes_fit_the_pane() {
	line := '日本語 🙂 naïve 🙂🙂 x'
	for cols in 0 .. 25 {
		got := sanitize_preview_line(line, cols)
		assert cells_of(got) <= cols
	}
	// a wide rune that would straddle the last cell is left out, not halved
	assert sanitize_preview_line('a日', 2) == 'a'
	assert sanitize_preview_line('日本', 3) == '日'
	assert sanitize_preview_line('日本', 4) == '日本'
	// zero-width runes stay with the cell before them
	assert sanitize_preview_line('🙂\u200d🙂', 2) == '🙂\u200d'
	assert sanitize_preview_line('e\u0301x', 1) == 'e\u0301'
}

fn test_read_preview_lines_matches_sanitize_for_wide_runes() {
	line := '日本語 🙂 naïve 🙂🙂 x\t🙂 tail'
	path := write_preview_fixture('wide_runes', '${line}\n')
	defer { os.rm(path) or {} }

	for cols in 0 .. 30 {
		read := read_preview_lines(path, 0, 1, cols)
		assert read.lines == [sanitize_preview_line(line, cols)]
		assert read.cut == (cells_of(read.lines[0]) < cells_of(sanitize_preview_line(line, 1000)))
	}
}

fn test_read_preview_lines_decodes_runes_split_across_blocks() {
	// each line puts a 4-byte emoji across the boundary between two reads
	for shift in 1 .. 4 {
		pad := 'x'.repeat(preview_read_block_size - shift)
		path := write_preview_fixture('split_${shift}', '${pad}🙂日\nnext\n')
		defer { os.rm(path) or {} }

		read := read_preview_lines(path, 0, 2, preview_read_block_size + 10)
		assert read.lines == ['${pad}🙂日', 'next']
	}
}
