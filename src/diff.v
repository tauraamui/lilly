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
	eof   bool
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

		left[i].ref = j
		right[j].ref = i

		i += dir
		j += dir
	}
}

fn diff(a []string, b []string) []Op {
	if same(a, b) { return a.map(fn (v string) Op { return Op{ kind: "same", value: v } })}
	if a.len == 0 { return b.map(fn (v string) Op { return Op{ kind: "ins", value: v } }) }
	if b.len == 0 { return a.map(fn (v string) Op { return Op{ kind: "del", value: v } }) }

	mut left := []Entry{}
	for i, cur in a {
		if left.len > 0 && left[left.len - 1].value == cur {
			left[left.len - 1].count += 1
			continue
		}
		left << Entry{
			value: cur,
			ref: -1,
			count: 1
		}
	}

	mut right := []Entry{}
	for i, cur in b {
		if right.len > 0 && right[right.len - 1].value == cur {
			right[right.len - 1].count += 1
			continue
		}
		right << Entry{
			value: cur,
			ref: -1,
			count: 1
		}
	}

	mut table := map[string]map[int]map[string]int{}
	add_to_table(mut table, left, "left")
	add_to_table(mut table, right, "right")

	find_unique(mut table, mut left, mut right)

	expand_unique(mut left, mut right, 1)
	expand_unique(mut left, mut right, -1)

	left << Entry{ ref: right.len, eof: true }

	return []
}

