module main

import tauraamui.bobatea.lib.draw
import tauraamui.bobatea as tea
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
