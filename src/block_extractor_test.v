module main

fn test_consecutive_integer_block_sequence_extractor() {
	mut sext := new_consecutive_integer_block_sequence_extractor(
		[0, 1, 2, 4, 5, 8, 7, 9]
	)
	assert sext.extract_blocks() == [
		Block{ start_idx: 0, length: 3 },
		Block{ start_idx: 3, length: 2 },
		Block{ start_idx: 5, length: 1 },
		Block{ start_idx: 6, length: 1 },
		Block{ start_idx: 7, length: 1 }
	]
}

fn test_non_integers_block_sequence_extractor() {
	mut sext := new_non_integers_block_sequence_extractor(
		[0, 1, HeckelSymbolTableEntry{ value: "a" }, 2, HeckelSymbolTableEntry{ value: "b" }, HeckelSymbolTableEntry{ value: "c" }, 3, 4]
	)
	assert sext.extract_blocks() == [Block{start_idx: 2, length: 1}, Block{start_idx: 4, length: 2}]
}
