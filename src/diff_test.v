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

fn test_diff_left_empty_right_not() {
	ops := diff([], ["a", "b", "c"])
	assert ops == [Op{kind: "ins", value: "a"}, Op{kind: "ins", value: "b"}, Op{kind: "ins", value: "c"}]
}

fn test_diff_right_empty_left_not() {
	ops := diff(["a", "b", "c"], [])
	assert ops == [Op{kind: "del", value: "a"}, Op{kind: "del", value: "b"}, Op{kind: "del", value: "c"}]
}
