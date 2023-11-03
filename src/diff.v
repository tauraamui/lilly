module main

import arrays

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
}

fn add_to_table(mut table map[string]map[int]map[string]int, arr []Entry, kind string) {
	arrays.each_indexed[Entry](arr, fn [mut table, kind] (idx int, token Entry) {
		if !(token.value in table) { table[token.value] = map[int]map[string]int{} }
		if !(token.count in table[token.value]) { table[token.value][token.count] = { "left": -1, "right": -1 } }
		v := table[token.value][token.count][kind]
		if v == - 1 { table[token.value][token.count][kind] = idx } else if v >= 0 { table[token.value][token.count][kind] = -2 }
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

fn diff(a []string, b []string) []Op {
	if same(a, b) { return a.map(fn (v string) Op { return Op{ kind: "same", value: v } })}
	if a.len == 0 { return b.map(fn (v string) Op { return Op{ kind: "ins", value: v } }) }
	if b.len == 0 { return a.map(fn (v string) Op { return Op{ kind: "del", value: v } }) }

	mut left := []Entry{}
	arrays.each_indexed[string](a, fn [mut left] (i int, cur string) {
		if left.len > 0 && left[left.len - 1].value == cur {
			left[left.len - 1].count += 1
			return
		}
		left << Entry{
			value: cur,
			ref: -1,
			count: 1
		}
	})

	mut right := []Entry{}
	arrays.each_indexed[string](b, fn [mut right] (i int, cur string) {
		if right.len > 0 && right[right.len - 1].value == cur {
			right[right.len - 1].count += 1
			return
		}
		right << Entry{
			value: cur,
			ref: -1,
			count: 1
		}
	})

	mut table := map[string]map[int]map[string]int{}
	add_to_table(mut table, left, "left")
	add_to_table(mut table, right, "right")

	find_unique(mut table, mut left, mut right)

	return []
}

