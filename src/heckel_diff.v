module main

struct HeckelSymbolTableEntry {
mut:
	value string
	oc    int
	nc    int
	olno  int
}

type HeckelSymbolTableEntryType = int | HeckelSymbolTableEntry

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

	println("NA => ${na}")
	println("OA => ${oa}")
}

