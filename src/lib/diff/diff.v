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

module diff

import arrays
import math

fn same(left []string, right []string) bool {
	if left.len != right.len {
		return false
	}
	for idx, cur in left {
		if right[idx] != cur {
			return false
		}
	}
	return true
}

pub struct Op {
	eof bool
pub:
	kind  string
	value string
pub mut:
	line_num int
}

struct Entry {
mut:
	value string
	ref   int
	count int
	eof   bool
}

fn add_to_table(mut table map[string]map[int]map[string]int, arr []Entry, kind string) {
	arrays.each_indexed[Entry](arr, fn [mut table, kind] (idx int, token Entry) {
		if token.value !in table {
			table[token.value] = map[int]map[string]int{}
		}
		if token.count !in table[token.value] {
			table[token.value][token.count] = {
				'left':  -1
				'right': -1
			}
		}
		v := table[token.value][token.count][kind]
		if v == -1 {
			table[token.value][token.count][kind] = idx
		} else if v >= 0 {
			table[token.value][token.count][kind] = -2
		}
	})
}

fn find_unique(mut table map[string]map[int]map[string]int, mut left []Entry, mut right []Entry) {
	for token in left {
		ref := table[token.value][token.count].clone()
		left_ref := ref['left']
		right_ref := ref['right']
		if left_ref >= 0 && right_ref >= 0 {
			left[left_ref].ref = right_ref
			right[right_ref].ref = left_ref
		}
	}
}

fn expand_unique(mut left []Entry, mut right []Entry, dir int) {
	for idx, token in left {
		if token.ref == -1 {
			return
		}
		mut i := idx + dir
		mut j := token.ref + dir
		lx := left.len
		rx := right.len

		for i >= 0 && j >= 0 && i < lx && j < rx {
			if left[i].value != right[j].value {
				break
			}

			left[i].ref = j
			right[j].ref = i

			i += dir
			j += dir
		}
	}
}

fn append_multiple(mut acc []Op, token Entry, kind string) {
	mut n := token.count
	for n > 0 {
		acc << Op{
			kind:  kind
			value: token.value
		}
		n -= 1
	}
}

fn calc_dist(l_target int, l_pos int, r_target int, r_pos int) int {
	return (l_target - l_pos) + (r_target - r_pos) +
		math.abs((l_target - l_pos) - (r_target - r_pos))
}

fn split_inclusive(str string, sep string, trim bool) []string {
	if str.len == 0 {
		return []
	}
	mut split := str.split(sep)
	if trim {
		split = split.filter(it.len > 0)
	}
	return arrays.map_indexed(split, fn [split, sep] (idx int, line string) string {
		return if idx < split.len - 1 { '${line}${sep}' } else { line }
	})
}

fn accumulate_changes(changes []Op, ffn fn (del string, ins string) []Op) []Op {
	mut del := []string{}
	mut ins := []string{}

	for ch in changes {
		match ch.kind {
			'del' { del << ch.value }
			'ins' { ins << ch.value }
			else {}
		}
	}

	if del.len == 0 || ins.len == 0 {
		return changes
	}

	return ffn(arrays.join_to_string(del, '', fn (elem string) string {
		return elem
	}), arrays.join_to_string(ins, '', fn (elem string) string {
		return elem
	}))
}

fn refine_changed(mut changes []Op, ffn fn (del string, ins string) []Op) []Op {
	mut ptr := -1

	mut acc := []Op{}
	changes << Op{
		kind: 'same'
		eof:  true
	}

	for idx, cur in changes {
		mut part := []Op{}
		if cur.kind == 'same' {
			if ptr >= 0 {
				part = accumulate_changes(changes[ptr..idx], ffn)
				if changes[idx - 1].kind != 'ins' {
					part = changes[ptr..idx].clone()
				}
				ptr = -1
			}
			acc << part
			if !cur.eof {
				acc << cur
			}
			return acc
		} else if ptr < 0 {
			ptr = idx
		}
	}
	return acc
}

fn process_diff(left []Entry, right []Entry) []Op {
	mut acc := []Op{}
	mut l_pos := 0
	mut r_pos := 0
	lx := left.len
	mut l_target := 0
	mut r_target := 0

	for l_pos < lx {
		l_target = l_pos

		for left[l_target].ref < 0 {
			l_target += 1
		}

		r_target = left[l_target].ref

		if r_target < r_pos {
			for l_pos < l_target {
				append_multiple(mut acc, left[l_pos], 'del')
				l_pos += 1
			}

			append_multiple(mut acc, left[l_pos], 'del')
			l_pos += 1
			continue
		}

		mut dist_1 := calc_dist(l_target, l_pos, r_target, r_pos)

		for r_seek := r_target - 1; dist_1 > 0 && r_seek >= r_pos; r_seek-- {
			if right[r_seek].ref < 0 {
				continue
			}
			if right[r_seek].ref < l_pos {
				continue
			}

			mut dist_2 := calc_dist(right[r_seek].ref, l_pos, r_seek, r_pos)
			if dist_2 < dist_1 {
				dist_1 = dist_2
				r_target = r_seek
				l_target = right[r_seek].ref
			}
		}

		for l_pos < l_target {
			append_multiple(mut acc, left[l_pos], 'del')
			l_pos += 1
		}

		for r_pos < r_target {
			append_multiple(mut acc, right[r_pos], 'ins')
			r_pos += 1
		}

		if left[l_pos].eof {
			break
		}

		count_diff := left[l_pos].count - right[r_pos].count

		if count_diff == 0 {
			append_multiple(mut acc, left[l_pos], 'same')
		} else if count_diff < 0 {
			append_multiple(mut acc, Entry{
				count: right[r_pos].count + count_diff
				value: right[r_pos].value
			}, 'same')
			append_multiple(mut acc, Entry{ count: -count_diff, value: right[r_pos].value },
				'ins')
		} else if count_diff > 0 {
			append_multiple(mut acc, Entry{
				count: left[l_pos].count - count_diff
				value: left[l_pos].value
			}, 'same')
			append_multiple(mut acc, Entry{ count: count_diff, value: left[l_pos].value },
				'del')
		}

		l_pos += 1
		r_pos += 1
	}
	return acc
}

fn add_new_count_existing(mut acc []Entry, cur string) {
	if acc.len != 0 && acc[acc.len - 1].value == cur {
		acc[acc.len - 1].count += 1
		return
	}
	acc << Entry{
		value: cur
		ref:   -1
		count: 1
	}
}

pub fn diff(a []string, b []string) []Op {
	if same(a, b) {
		return a.map(fn (v string) Op {
			return Op{ kind: 'same', value: v }
		})
	}
	if a.len == 0 {
		return b.map(fn (v string) Op {
			return Op{ kind: 'ins', value: v }
		})
	}
	if b.len == 0 {
		return a.map(fn (v string) Op {
			return Op{ kind: 'del', value: v }
		})
	}

	// TODO(tauraamui) -> comapre this population logic with JS reduce
	mut left := []Entry{}
	for cur in a {
		add_new_count_existing(mut left, cur)
	}

	mut right := []Entry{}
	for cur in b {
		add_new_count_existing(mut right, cur)
	}

	mut table := map[string]map[int]map[string]int{}
	add_to_table(mut table, left, 'left')
	add_to_table(mut table, right, 'right')

	find_unique(mut table, mut left, mut right)

	expand_unique(mut left, mut right, 1)
	expand_unique(mut left, mut right, -1)

	left << Entry{
		ref: right.len
		eof: true
	}

	return process_diff(left, right)
}

fn diff_lines(a string, b string, trim bool) []Op {
	return diff(split_inclusive(a, '\n', trim), split_inclusive(b, '\n', trim))
}

fn diff_words(a string, b string, trim bool) []Op {
	return diff(split_inclusive(a, ' ', trim), split_inclusive(b, ' ', trim))
}

fn diff_hybrid(a string, b string, trim bool) []Op {
	mut lines_diff := diff_lines(a, b, trim)
	return refine_changed(mut lines_diff, fn [trim] (del string, ins string) []Op {
		return diff_words(del, ins, trim)
	})
}
