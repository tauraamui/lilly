module files

import os

pub interface Finder {
	files() []string
mut:
	search(root string)!
}

type Lister = fn (path string) ![]string

struct StdlibBasedFinder {
	ls Lister @[required]
mut:
	files []string
}

struct ToolBasedFinder {
mut:
	files []string
}

pub fn new_finder() Finder {
	$if darwin || stdfinder ? {
		return StdlibBasedFinder{ ls: os.ls }
	}
	return ToolBasedFinder{}
}

fn (mut mf ToolBasedFinder) search(root string) ! {
	// Use external tools for efficient file discovery, similar to telescope
	// Priority: rg > fd > find
	if os.exists_in_system_path('rg') {
		result := os.execute('rg --files --color never')
		if result.exit_code == 0 {
			mf.files = result.output.split_into_lines().filter(it.len > 0)
			return
		}
	}

	if os.exists_in_system_path('fd') {
		result := os.execute('fd --type f --color never')
		if result.exit_code == 0 {
			mf.files = result.output.split_into_lines().filter(it.len > 0)
			return
		}
	}

	// Fallback to basic find command
	result := os.execute('find . -type f')
	if result.exit_code == 0 {
		mf.files = result.output.split_into_lines().filter(it.len > 0)
		return
	}

	return error('failed to search')
}

fn (tf ToolBasedFinder) files() []string {
	return tf.files
}

fn (mut sf StdlibBasedFinder) search(root string) ! {
	sf.files = sf.ls(root) or { []string{} }
}

fn (sf StdlibBasedFinder) files() []string {
	return sf.files
}

