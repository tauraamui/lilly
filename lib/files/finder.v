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

module files

import os

@[params]
pub struct WalkParams {
pub:
	ls        Lister @[required]
	hidden    bool
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

pub fn new_finder() Finder {
	return StdlibBasedFinder{
		ls: os.ls
	}
}

fn (mut sf StdlibBasedFinder) search(root string) {
	sf.files = walk(root, ls: sf.ls)
}

fn (sf StdlibBasedFinder) files() []string {
	return sf.files
}
