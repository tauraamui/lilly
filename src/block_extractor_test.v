module main

fn test_sequence_extractor() {
	mut seq_extractor := SequenceExtractor{
		seq: [0, 1, "a", 2, "b", "c", 3, 4]
		prev: none
		block_start_idx: 0
		block_len: 0
		in_block: false
		open_block_cond: fn(prev ?SequenceType, curr SequenceType) bool {
			return !(curr is int)
		}
		close_block_cond: fn(prev ?SequenceType, curr SequenceType) bool {
			return curr is int
		}
	}

	assert seq_extractor.extract_blocks() == [Block{start_idx: 2, length: 1}, Block{start_idx: 4, length: 2}]
}
