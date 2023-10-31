module main

type BlocksType = []Block

struct Block {
	start_idx int
	length    int
}

type SequenceType = int | string

struct SequenceExtractor {
mut:
	seq               []SequenceType
	prev              ?SequenceType
	open_block_cond   ?fn(prev ?SequenceType, curr SequenceType) bool
	close_block_cond  ?fn(prev ?SequenceType, curr SequenceType) bool
	return_block_cond ?fn(block_start_idx int, block_len int) Block
	block_start_idx   int
	block_len         int
	in_block          bool
	yield_last_block  bool
}

fn (mut sequence_extractor SequenceExtractor) extract_blocks() BlocksType {
	mut blocks := []Block{}
	sequence_extractor.yield_last_block = true

	for idx, i in sequence_extractor.seq {
		// close block
		if sequence_extractor.close_block(sequence_extractor.prev, i) && sequence_extractor.in_block {
			blocks << sequence_extractor.return_block(sequence_extractor.block_start_idx, sequence_extractor.block_len)
			sequence_extractor.in_block = false
		}

		// open block
		if !sequence_extractor.in_block && sequence_extractor.open_block(sequence_extractor.prev, i) {
			sequence_extractor.block_start_idx = idx
			sequence_extractor.block_len = 0
			sequence_extractor.in_block = true
		}

		// increase block
		sequence_extractor.prev = i
		sequence_extractor.block_len += 1
	}

	// last block
	if sequence_extractor.in_block && sequence_extractor.yield_last_block {
		blocks << sequence_extractor.return_block(sequence_extractor.block_start_idx, sequence_extractor.block_len)
	}

	return blocks
}

fn (sequence_extractor SequenceExtractor) open_block(prev ?SequenceType, curr SequenceType) bool {
	cond := sequence_extractor.open_block_cond or { fn (prev ?SequenceType, curr SequenceType) bool { return false } }
	return cond(prev, curr)
}

fn (sequence_extractor SequenceExtractor) close_block(prev ?SequenceType, curr SequenceType) bool {
	cond := sequence_extractor.close_block_cond or { fn (prev ?SequenceType, curr SequenceType) bool { return false } }
	return cond(prev, curr)
}

fn (sequence_extractor SequenceExtractor) return_block(block_start_idx int, block_len int) Block {
	cond := sequence_extractor.return_block_cond or {
		fn(block_start_idx int, block_len int) Block { return Block{ start_idx: block_start_idx, length: block_len } }
	}
	return cond(block_start_idx, block_len)
}




