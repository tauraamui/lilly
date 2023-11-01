module main

fn test_non_integers_block_sequence_extractor() {
	mut sext := new_non_integers_block_sequence_extractor(
		[0, 1, HeckelSymbolTableEntry{ value: "a" }, 2, HeckelSymbolTableEntry{ value: "b" }, HeckelSymbolTableEntry{ value: "c" }, 3, 4]
	)
	assert sext.extract_blocks() == [Block{start_idx: 2, length: 1}, Block{start_idx: 4, length: 2}]
}
