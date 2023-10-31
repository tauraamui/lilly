module main

fn test_non_integers_block_sequence_extractor() {
	mut sext := new_non_integers_block_sequence_extractor([0, 1, "a", 2, "b", "c", 3, 4])
	assert sext.extract_blocks() == [Block{start_idx: 2, length: 1}, Block{start_idx: 4, length: 2}]
}
