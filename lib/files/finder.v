module files

import os

@[params]
pub struct WalkParams {
pub:
	ls Lister @[required]
	hidden bool
	threshold int = 100
}

pub fn walk(path string, opts WalkParams) []string {
	ch := chan []string{cap: 100}

	go walk_worker(path, ch, opts)

	mut res := []string{}
	for {
		paths := <-ch or { break }
		res << paths
	}

	return res
}

fn walk_worker(path string, ch chan []string, opts WalkParams) {
	impl_walk_concurrent(path, ch, opts)
	ch.close()
}

fn impl_walk_concurrent(path string, ch chan []string, opts WalkParams) {
	if !os.is_dir(path) {
		return
	}

	files := os.ls(path) or { return }

	should_parallelize := files.len > opts.threshold

	separator := if path.ends_with(os.path_separator) { '' } else { os.path_separator }
	mut local_files := []string{}
	mut subdirs := []string{}

	for file in files {
		if !opts.hidden && file.starts_with('.') {
			continue
		}
		p := path + separator + file
		if os.is_dir(p) && !os.is_link(p) {
			subdirs << p
		} else {
			local_files << p
		}
	}

	if local_files.len > 0 {
		ch <- local_files
	}

	if should_parallelize {
		mut threads := []thread{}
		for subdir in subdirs {
			threads << go impl_walk_concurrent(subdir, ch, opts)
		}
		threads.wait()
	} else {
		for subdir in subdirs {
			impl_walk_concurrent(subdir, ch, opts)
		}
	}
}

pub interface Finder {
	files() []string
mut:
	search(root string)
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

fn (mut mf ToolBasedFinder) search(root string) {
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
}

fn (tf ToolBasedFinder) files() []string {
	return tf.files
}

fn (mut sf StdlibBasedFinder) search(root string) {
	// sf.files = sf.ls(root) or { []string{} }
	sf.files = walk(root, ls: os.ls)
}

fn (sf StdlibBasedFinder) files() []string {
	return sf.files
}

