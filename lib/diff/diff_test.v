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

module diff

import rand

// apply rebuilds new from old and the hunks, so a test can check the hunks
// describe the change exactly
fn apply(old []string, new []string, hunks []Hunk) []string {
	mut out := []string{}
	mut i := 0
	for h in hunks {
		assert h.old_start >= i
		out << old[i..h.old_start]
		out << new[h.new_start..h.new_start + h.new_count]
		i = h.old_start + h.old_count
	}
	out << old[i..]
	return out
}

fn edit_count(hunks []Hunk) int {
	mut n := 0
	for h in hunks {
		n += h.old_count + h.new_count
	}
	return n
}

fn test_identical_text_has_no_hunks() {
	assert lines(['a', 'b'], ['a', 'b']) == []
	assert lines([]string{}, []string{}) == []
}

fn test_insertion_removes_nothing() {
	hunks := lines(['a', 'c'], ['a', 'b', 'c'])
	assert hunks == [Hunk{
		old_start: 1
		old_count: 0
		new_start: 1
		new_count: 1
	}]
}

fn test_deletion_anchors_on_the_line_that_follows() {
	hunks := lines(['a', 'b', 'c'], ['a', 'c'])
	assert hunks == [Hunk{
		old_start: 1
		old_count: 1
		new_start: 1
		new_count: 0
	}]
}

fn test_replacement_is_one_hunk() {
	hunks := lines(['a', 'b', 'c'], ['a', 'x', 'y', 'c'])
	assert hunks == [Hunk{
		old_start: 1
		old_count: 1
		new_start: 1
		new_count: 2
	}]
}

fn test_separate_changes_are_separate_hunks() {
	old := ['1', '2', '3', '4', '5', '6']
	new := ['1', 'two', '3', '4', '5', '6', '7']
	hunks := lines(old, new)
	assert hunks.len == 2
	assert apply(old, new, hunks) == new
}

fn test_from_and_to_empty() {
	assert lines([]string{}, ['a', 'b']) == [Hunk{
		old_start: 0
		old_count: 0
		new_start: 0
		new_count: 2
	}]
	assert lines(['a', 'b'], []string{}) == [Hunk{
		old_start: 0
		old_count: 2
		new_start: 0
		new_count: 0
	}]
}

fn test_random_edits_rebuild_the_new_text_minimally() {
	rand.seed([u32(7), 11])
	for _ in 0 .. 200 {
		mut old := []string{}
		for _ in 0 .. rand.intn(30) or { 0 } {
			old << (rand.intn(5) or { 0 }).str()
		}
		mut new := old.clone()
		for _ in 0 .. rand.intn(6) or { 0 } {
			at := rand.intn(new.len + 1) or { 0 }
			if rand.intn(2) or { 0 } == 0 || new.len == 0 {
				new.insert(at, (rand.intn(5) or { 0 }).str())
			} else if at < new.len {
				new.delete(at)
			}
		}
		hunks := lines(old, new)
		assert apply(old, new, hunks) == new
		// a shortest edit script never needs more edits than were made
		assert edit_count(hunks) <= 2 * 6
	}
}

fn test_a_wholesale_rewrite_falls_back_to_one_hunk() {
	mut old := []string{}
	mut new := []string{}
	for i in 0 .. max_edits {
		old << 'old ${i}'
		new << 'new ${i}'
	}
	old << 'same'
	new << 'same'
	hunks := lines(old, new)
	assert hunks == [Hunk{
		old_start: 0
		old_count: max_edits
		new_start: 0
		new_count: max_edits
	}]
}
