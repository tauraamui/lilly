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

fn test_should_return_deletions_at_end() {
	assert diff(
			["a", "b", "c"],
			["a", "b"]
		) == [
			Op{ value: "a", kind: "same" },
			Op{ value: "b", kind: "same" },
			Op{ value: "c", kind: "del" }
		]
}

fn test_should_return_insertions_at_beginning() {
	assert diff(
			["a", "b", "c"],
			["z", "a", "b", "c"]
		) == [
			Op{ value: "z", kind: "ins" },
			Op{ value: "a", kind: "same" },
			Op{ value: "b", kind: "same" },
			Op{ value: "c", kind: "same" }
		]
}

fn test_should_return_insertions_at_end() {
	assert diff(
		["a", "b", "c"],
		["a", "b", "c", "z"]
	) == [
		Op{ value: "a", kind: "same" },
		Op{ value: "b", kind: "same" },
		Op{ value: "c", kind: "same" },
		Op{ value: "z", kind: "ins" }
	]
}

fn test_should_deal_with_repeats() {
	assert diff(
		["a", "b", "b", "b", "a"],
		["c", "b", "b", "b", "c"]
	) == [
		Op{ value: "a", kind: "del" },
		Op{ value: "c", kind: "ins" },
		Op{ value: "b", kind: "same" },
		Op{ value: "b", kind: "same" },
		Op{ value: "b", kind: "same" },
		Op{ value: "a", kind: "del" },
		Op{ value: "c", kind: "ins" }
	]
}

// TODO(tauraamui): the following tests are all condencing special introspection tests.
// They currently do not work. Need to investigate.
/*
fn test_should_treat_repeat_tokens_as_different_in_passes_4_and_5() {
	assert diff(
		["f", "f", "c"],
		["f", "c"]
	) == [
		Op{ value: "f", kind: "same" },
		Op{ value: "f", kind: "del" },
		Op{ value: "c", kind: "same" }
	]
}

fn test_should_reduce_equivalant_del_ins_sequences() {
	assert diff(
		["f", "f", "f", "c"],
		["f", "f", "c"]
	) == [
		Op{ value: "f", kind: "same" },
		Op{ value: "f", kind: "same" },
		Op{ value: "f", kind: "del" },
		Op{ value: "c", kind: "same" }
	]
}
*/

fn test_should_recognise_transpositions_as_individual_edits() {
	assert diff(
		["a", "b", "c", "d", "e"],
		["a", "d", "c", "b", "e"]
	) == [
		Op{ value: "a", kind: "same" },
		Op{ value: "b", kind: "del" },
		Op{ value: "d", kind: "ins" },
		Op{ value: "c", kind: "same" },
		Op{ value: "d", kind: "del" },
		Op{ value: "b", kind: "ins" },
		Op{ value: "e", kind: "same" }
	]
}

fn test_should_handle_a_more_complex_transposition() {
	assert diff(
		["a", "b", "c", "u", "x", "d", "e"],
		["a", "d", "u", "c", "x", "b", "e"]
	) == [
		Op{ value: "a", kind: "same" },
		Op{ value: "b", kind: "del" },
		Op{ value: "d", kind: "ins" },
		Op{ value: "u", kind: "ins" },
		Op{ value: "c", kind: "same" },
		Op{ value: "u", kind: "del" },
		Op{ value: "x", kind: "same" },
		Op{ value: "d", kind: "del" },
		Op{ value: "b", kind: "ins" },
		Op{ value: "e", kind: "same" }
	]
}

fn test_should_handle_a_more_complex_transposition_with_large_offset() {
	assert diff(
		["a", "b", "c", "u", "x", "d", "e"],
		["z", "z", "z", "z", "z", "z", "z", "z", "z", "z", "a", "d", "u", "c", "x", "b", "e"]
	) == [
		Op{ value: "z", kind: "ins" },
		Op{ value: "z", kind: "ins" },
		Op{ value: "z", kind: "ins" },
		Op{ value: "z", kind: "ins" },
		Op{ value: "z", kind: "ins" },
		Op{ value: "z", kind: "ins" },
		Op{ value: "z", kind: "ins" },
		Op{ value: "z", kind: "ins" },
		Op{ value: "z", kind: "ins" },
		Op{ value: "z", kind: "ins" },
		Op{ value: "a", kind: "same" },
		Op{ value: "b", kind: "del" },
		Op{ value: "d", kind: "ins" },
		Op{ value: "u", kind: "ins" },
		Op{ value: "c", kind: "same" },
		Op{ value: "u", kind: "del" },
		Op{ value: "x", kind: "same" },
		Op{ value: "d", kind: "del" },
		Op{ value: "b", kind: "ins" },
		Op{ value: "e", kind: "same" }
	]
}

fn test_should_handle_extra_deletions_with_previously_emitted_change() {
	assert diff(
		["a", "b", "c", "v", "v", "d", "e"],
		["a", "d", "c", "b", "e"]
	) == [
		Op{ value: "a", kind: "same" },
		Op{ value: "b", kind: "del" },
		Op{ value: "d", kind: "ins" },
		Op{ value: "c", kind: "same" },
		Op{ value: "v", kind: "del" },
		Op{ value: "v", kind: "del" },
		Op{ value: "d", kind: "del" },
		Op{ value: "b", kind: "ins" },
		Op{ value: "e", kind: "same" }
	]
}

fn test_should_handle_neighbouring_transposition() {
	assert diff(
		["a", "b", "c", "d"],
		["a", "c", "b", "d"]
	) == [
		Op{ value: "a", kind: "same" },
		Op{ value: "c", kind: "ins" },
		Op{ value: "b", kind: "same" },
		Op{ value: "c", kind: "del" },
		Op{ value: "d", kind: "same" }
	]
}

fn test_should_handle_multiple_repeats_of_different_lengths() {
	assert diff(
		["a", "b", "b", "c", "b", "b", "b", "d"],
		["e", "b", "b", "f", "b", "b", "b", "g"]
	) == [
		Op{ value: "a", kind: "del" },
		Op{ value: "e", kind: "ins" },
		Op{ value: "b", kind: "same" },
		Op{ value: "b", kind: "same" },
		Op{ value: "c", kind: "del" },
		Op{ value: "f", kind: "ins" },
		Op{ value: "b", kind: "same" },
		Op{ value: "b", kind: "same" },
		Op{ value: "b", kind: "same" },
		Op{ value: "d", kind: "del" },
		Op{ value: "g", kind: "ins" }
	]
}

fn test_should_diff_text_by_lines() {
	assert diff_lines(
		"a\nb\nc",
		"a\nd\nc",
		false
	) == [
		Op{ value: "a\n", kind: "same" },
		Op{ value: "b\n", kind: "del" },
		Op{ value: "d\n", kind: "ins" },
		Op{ value: "c", kind: "same" }
	]
}

fn test_should_diff_text_by_words() {
	assert diff_words(
		"a b c",
		"a d c",
		false
	) == [
		Op{ value: "a ", kind: "same" },
		Op{ value: "b ", kind: "del" },
		Op{ value: "d ", kind: "ins" },
		Op{ value: "c", kind: "same" }
	]
}

fn test_should_preserve_spaces_when_trim_is_false() {
	assert diff_words(
		"a  b  c",
		"a b c",
		false
	) == [
		Op{ value: "a ", kind: "same" },
		Op{ value: " ", kind: "del" },
		Op{ value: "b ", kind: "same" },
		Op{ value: " ", kind: "del" },
		Op{ value: "c", kind: "same" }
	]
}

fn test_should_ignore_consecutive_spaces_when_trim_is_true() {
	assert diff_words(
		"a  b  c",
		"a b c",
		true
	) == [
		Op{ value: "a ", kind: "same" },
		Op{ value: "b ", kind: "same" },
		Op{ value: "c", kind: "same" }
	]
}

fn test_should_diff_text_by_lines_and_words() {
	assert diff_hybrid(
		"a b\nc d\nz z\ne f\ng h",
		"a b\ni j\nz z\nk f\ng h",
		false
	) == [
		Op{ value: "a b\n", kind: "same" }
	]
}

fn test_append_multiple() {
	mut acc := []Op{}
	append_multiple(mut acc, Entry{ count: 3, value: "some text" }, "ins")
	assert acc == [
		Op{ value: "some text", kind: "ins" },
		Op{ value: "some text", kind: "ins" },
		Op{ value: "some text", kind: "ins" }
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

fn test_add_new_count_existing() {
	mut acc := []Entry{}

	for cur in ["a", "a", "b"] {
		add_new_count_existing(mut acc, cur)
	}

	assert acc == [
		Entry{
			value: "a"
			ref: -1
			count: 2
			eof: false
		},
		Entry{
			value: "b"
			ref: -1
			count: 1
			eof: false
		}
	]
}

