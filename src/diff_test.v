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

fn test_should_return_deletions_at_beginning() {
	assert diff(["a", "b", "c"], ["b", "c"]) == [
		Op{ value: "a", kind: "del" },
		Op{ value: "b", kind: "same" },
		Op{ value: "c", kind: "same" }
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

