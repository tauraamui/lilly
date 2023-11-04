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

fn test_should_return_all_insertions() {
	assert diff([], ["a", "b", "c"]) == [
		Op{ value: "a", kind: "ins" },
		Op{ value: "b", kind: "ins" },
		Op{ value: "c", kind: "ins" }
	]
}

fn test_should_return_all_insertions_including_repeats() {
	assert diff([], ["a", "b", "b", "c"]) == [
		Op{ value: "a", kind: "ins" },
		Op{ value: "b", kind: "ins" },
		Op{ value: "b", kind: "ins" },
		Op{ value: "c", kind: "ins" }
	]
}

fn test_should_return_all_deletions() {
	assert diff(["a", "b", "c"], []) == [
		Op{ value: "a", kind: "del" },
		Op{ value: "b", kind: "del" },
		Op{ value: "c", kind: "del" }
	]
}

fn test_should_return_all_deletions_including_repeats() {
	assert diff(["a", "b", "b", "c"], []) == [
		Op{ value: "a", kind: "del" },
		Op{ value: "b", kind: "del" },
		Op{ value: "b", kind: "del" },
		Op{ value: "c", kind: "del" }
	]
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

/*
fn test_diff_single_char() {
	ops := diff(["x"], ["s"])
	assert ops == [
		Op{kind: "del", value: "x"},
		Op{kind: "ins", value: "s"}
	]
}
*/

/*
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
*/

/*
fn test_diff_buffer_pre_edit_to_buffer_post_edit() {
	ops := diff([
		"2. second line",
		"1. first line",
	], [
		"1. first lined",
		"2. second line"
	])

	assert ops == []
}
*/
