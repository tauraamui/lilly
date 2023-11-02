module main

struct HeckelSymbolTableEntry {
mut:
	value string
	oc    int
	nc    int
	olno  int
}

type HeckelSymbolTableEntryType = []int | int | HeckelSymbolTableEntry

fn run_diff(a []string, b []string) {
	mut st := map[string]HeckelSymbolTableEntryType{}
	mut na := []HeckelSymbolTableEntryType{}
	mut oa := []HeckelSymbolTableEntryType{}

	// pass one
	for _, i in a {
		if i in st {
			v := st[i]
			if v is HeckelSymbolTableEntry {
				mut vv := v as HeckelSymbolTableEntry
				vv.nc += 1
				st[i] = vv
			}
		} else {
			st[i] = HeckelSymbolTableEntry{ value: i, nc: 1 }
		}
		na << st[i]
	}

	// pass two
	for idx, i in b {
		if i in st {
			if st[i] is HeckelSymbolTableEntry {
				mut v := st[i] as HeckelSymbolTableEntry
				v.oc += 1
				v.olno = idx
				st[i] = v
			}
		} else {
			st[i] = HeckelSymbolTableEntry{ value: i, oc: 1 }
		}
		oa << st[i]
	}

	// pass three
	for i in 0..na.len {
		if na[i] is HeckelSymbolTableEntry {
			nae := na[i] as HeckelSymbolTableEntry
			if nae.nc == 1 && nae.oc == 1 {
				olno := nae.olno
				na[i] = olno
				oa[olno] = i
			}
		}
	}

	// pass four
	for i in 0..na.len {
		if na[i] is int {
			j := na[i] as int
			if na[i + 1] is HeckelSymbolTableEntry {
				if na[i + 1] == oa[j + 1] {
					oa[j + 1] = i + 1
					na[i + 1] = j + 1
				}
			}
		}
	}

	// pass five
	for i := na.len-1; i >= 1; i-- {
		if na[i] is int {
			j := na[i] as int
			if na[i - 1] is HeckelSymbolTableEntry {
				if na[i - 1] == oa[j - 1] && i >= 1 && j >= 1 {
					oa[j - 1] = i - 1
					na[i - 1] = j - 1
				}
			}
		}
	}

	insert_opcodes := generate_insert_opcodes(oa)
	println("${insert_opcodes}")
	mut delete_opcodes := generate_delete_opcodes(na)
	println("${delete_opcodes}")
	mut move_opcodes := []OpCode{}
	mut moved_opcodes := []OpCode{}
	mut equal_opcodes := []OpCode{}

	dict := { "move": move_opcodes, "moved": moved_opcodes, "equal": equal_opcodes }

	generate_move_and_equal_opcodes(na)

	mut ipos := 0
	mut jpos := 0
	mut result := []OpCode{}
	for {
		if delete_opcodes.len == 0 { break }
		if delete_opcodes.len > 0 && delete_opcodes[0].i1 == ipos {
			opcode := delete_opcodes.pop()
			result << OpCode{ tag: opcode.tag, i1: opcode.i1, i2: opcode.i2, j1: jpos, j2: jpos }
			ipos = opcode.i2
			continue
		}
	}
	println("${result}")
}

struct OpCode {
	tag string
	i1  int
	i2  int
	j1  int
	j2  int
}

struct OpBlock {
	i int
	n HeckelSymbolTableEntryType
	w int
}

struct IndexedMove {
	idx int
	i   int
}

fn generate_move_and_equal_opcodes(na []HeckelSymbolTableEntryType) []OpCode {
	mut na_indexed_moves := []HeckelSymbolTableEntryType{}
	for idx, i in na {
		if i is int { na_indexed_moves << [int(idx), i] }
	}
	mut sext := new_consecutive_vector_block_sequence_extractor(na_indexed_moves)
	return []
}

fn generate_insert_opcodes(oa []HeckelSymbolTableEntryType) []OpCode {
	mut block_extractor := new_non_integers_block_sequence_extractor(oa)
	insert_blocks := block_extractor.extract_blocks().map(fn [oa] (block Block) OpBlock {
		return OpBlock{
			i: block.start_idx
			n: oa[block.start_idx]
			w: block.length
		}
	})
	mut opcodes := []OpCode{}
	for b in insert_blocks {
		if b.n is HeckelSymbolTableEntry {
			bn := b.n as HeckelSymbolTableEntry
			opcodes << OpCode{ tag: "insert", i1: bn.olno, i2: bn.olno, j1: b.i, j2: b.i + b.w }
		}
	}
	return opcodes
}

fn generate_delete_opcodes(na []HeckelSymbolTableEntryType) []OpCode {
	mut block_extractor := new_non_integers_block_sequence_extractor(na)
	delete_blocks := block_extractor.extract_blocks().map(fn [na] (block Block) OpBlock {
		return OpBlock{
			i: block.start_idx
			n: na[block.start_idx]
			w: block.length
		}
	})
	mut opcodes := []OpCode{}
	for b in delete_blocks {
		if b.n is HeckelSymbolTableEntry {
			bn := b.n as HeckelSymbolTableEntry
			opcodes << OpCode{ tag: "delete", i1: b.i, i2: b.i + b.w, j1: bn.olno, j2: bn.olno }
		}
	}
	return opcodes
}

