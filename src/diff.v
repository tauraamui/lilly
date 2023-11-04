module main

import arrays
import math

fn same(left []string, right []string) bool {
	if left.len != right.len { return false }
	for idx, cur in left {
		if right[idx] != cur { return false }
	}
	return true
}

struct Op {
	kind  string
	value string
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
		if !(token.value in table) { table[token.value] = map[int]map[string]int{} }
		if !(token.count in table[token.value]) { table[token.value][token.count] = { "left": -1, "right": -1 } }
		v := table[token.value][token.count][kind]
		if v == -1 { table[token.value][token.count][kind] = idx } else if v >= 0 { table[token.value][token.count][kind] = -2 }
	})
}

fn find_unique(mut table map[string]map[int]map[string]int, mut left []Entry, mut right []Entry) {
	for token in left {
		ref := table[token.value][token.count].clone()
		if ref["left"] >= 0 && ref["right"] >= 0 {
			left_token := left[ref["left"]]
			right_token := right[ref["right"]]
			left[ref["left"]] = Entry{ value: left_token.value, ref: ref["right"], count: left_token.count }
			right[ref["right"]] = Entry{ value: right_token.value, ref: ref["left"], count: right_token.count }
		}
	}
}

fn expand_unique(mut left []Entry, mut right []Entry, dir int) {
	for idx, token in left {
		if token.ref == -1 { return }
		mut i := idx + dir
		mut j := token.ref + dir
		lx := left.len
		rx := right.len

		for i >= 0 && j >= 0 && i < lx && j < rx {
			if left[i].value != right[j].value { break }
		}

		if i == lx || i < 0 { break }
		if j == rx || j < 0 { break }

		left[i].ref = j
		right[j].ref = i

		i += dir
		j += dir
	}
}

fn append_multiple(mut acc []Op, token Entry, kind string) {
	mut n := token.count
	for _ in 0..n {
		acc << Op{ kind: kind, value: token.value }
	}
}

fn calc_dist(l_target int, l_pos int, r_target int, r_pos int) int {
	return (l_target - l_pos) + (r_target - r_pos) + math.abs((l_target - l_pos) - (r_target - r_pos))
}

fn process_diff(left []Entry, right []Entry) []Op {
	mut acc := []Op{}
	mut l_pos := 0
	mut r_pos := 0
	lx := left.len
	rx := right.len
	mut l_token := Entry{}
	mut r_token := Entry{}
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
				append_multiple(mut acc, left[l_pos], "del")
			}

			append_multiple(mut acc, left[l_pos++], "del")
			continue
		}

		r_token = right[r_target]

		mut dist_1 := calc_dist(l_target, l_pos, r_target, r_pos)

		for r_seek := r_target - 1; dist_1 > 0 && r_seek >= r_pos; r_seek-- {
			if right[r_seek].ref < 0 { continue }
			if right[r_seek].ref < l_pos { continue }

			mut dist_2 := calc_dist(right[r_seek].ref, l_pos, r_seek, r_pos)
			if dist_2 < dist_1 {
				dist_1 = dist_2
				r_target = r_seek
				l_target = right[r_seek].ref
			}
		}

		for l_pos < l_target {
			append_multiple(mut acc, left[l_pos++], "del")
		}

		for r_pos < r_target {
			append_multiple(mut acc, right[r_pos++], "ins")
		}

		if left[l_pos].eof { break }

		count_diff := left[l_pos].count - right[r_pos].count

		if count_diff == 0 {
			append_multiple(mut acc, left[l_pos], "same")
		} else if count_diff < 0 {
			append_multiple(mut acc, Entry{ count: right[r_pos].count + count_diff, value: right[r_pos].value }, "same")
			append_multiple(mut acc, Entry{ count: -count_diff, value: right[r_pos].value }, "ins")
		} else if count_diff > 0 {
			append_multiple(mut acc, Entry{ count: left[l_pos].count - count_diff, value: left[l_pos].value }, "same")
			append_multiple(mut acc, Entry{ count: count_diff, value: left[l_pos].value }, "del")
		}

		l_pos += 1
		r_pos += 1
	}
	return acc
}

fn reduce(mut acc []Entry, cur string) {
	if acc.len != 0 && acc[acc.len - 1].value == cur {
		acc[acc.len - 1].count += 1
		return
	}
	acc << Entry{
		value: cur,
		ref: -1,
		count: 1
	}
}

fn diff(a []string, b []string) []Op {
	if same(a, b) { return a.map(fn (v string) Op { return Op{ kind: "same", value: v } })}
	if a.len == 0 { return b.map(fn (v string) Op { return Op{ kind: "ins", value: v } }) }
	if b.len == 0 { return a.map(fn (v string) Op { return Op{ kind: "del", value: v } }) }

	// TODO(tauraamui) -> comapre this population logic with JS reduce
	mut left := []Entry{}
	for cur in a {
		reduce(mut left, cur)
	}

	mut right := []Entry{}
	for cur in b {
		reduce(mut right, cur)
	}

	mut table := map[string]map[int]map[string]int{}
	add_to_table(mut table, left, "left")
	add_to_table(mut table, right, "right")

	find_unique(mut table, mut left, mut right)

	expand_unique(mut left, mut right, 1)
	expand_unique(mut left, mut right, -1)

	left << Entry{ ref: right.len, eof: true }

	return process_diff(left, right)
}

