module main

fn test_same_check_is_matching() {
	assert same(["a", "b", "c"], ["a", "b", "c"])
}

fn test_same_check_is_different() {
	assert !same(["bb", "c", "f"], ["a", "b", "c"])
}

fn test_diff_same() {
	ops := diff(["a", "b", "c"], ["a", "b", "c"])
	assert ops == [Op{kind: "same", value: "a"}, Op{kind: "same", value: "b"}, Op{kind: "same", value: "c"}]
}

fn test_add_to_table() {
	mut table := map[string]map[int]map[string]int{}

	mut left_entries := [Entry{value: "a", ref: -1, count: 1}]
	mut right_entries := [Entry{value: "a", ref: -1, count: 1}, Entry{value: "b", ref: -1, count: 1}]

	add_to_table(mut table, left_entries, "left")
	add_to_table(mut table, right_entries, "right")

	assert table == {'a': {1: {'left': 0, 'right': 0}}, 'b': {1: {'left': -1, 'right': 1}}}
}

fn test_diff_left_empty_right_not() {
	ops := diff([], ["a", "b", "c"])
	assert ops == [Op{kind: "ins", value: "a"}, Op{kind: "ins", value: "b"}, Op{kind: "ins", value: "c"}]
}

fn test_diff_right_empty_left_not() {
	ops := diff(["a", "b", "c"], [])
	assert ops == [Op{kind: "del", value: "a"}, Op{kind: "del", value: "b"}, Op{kind: "del", value: "c"}]
}

fn test_diff_left_and_right() {
	ops := diff(["c", "c", "b", "c", "d"], ["a", "b", "c"])
	assert ops == [
		Op{kind: "del", value: "c"},
		Op{kind: "del", value: "c"},
		Op{kind: "ins", value: "a"},
		Op{kind: "same", value: "b"},
		Op{kind: "same", value: "c"},
		Op{kind: "del", value: "d"}
	]
}
