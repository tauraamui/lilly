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

import tauraamui.bobatea.lib.draw
import tauraamui.bobatea as tea
import lib.petal.theme
import lib.files

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
		fp = m
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
