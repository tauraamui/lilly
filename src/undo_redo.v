module main

import datatypes

struct UndoRedoHistory {
	stack datatypes.Queue[Modification]
}

enum MType as u8 {
	insert
	change
	delete
}

struct Modification {
	mtype    MType
	contents string
	line_num int
}

struct Line {
mut:
	old_occurances              int
	new_occurances  		    int
	old_line_number             int
	actually_other_line_num_ref bool
	other_line_num              int
}

fn build_map_of_files(old []string, new []string) {
	mut table := map[string]Line{}

	mut oa := []Line{ len: old.len }
	mut na := []Line{ len: new.len }

	defer { println("TABLE -> ${table}") }
	defer { println("NA -> ${na}") }
	defer { println("OA -> ${oa}") }

	for i, line in new {
		if table[line] == Line{} {
			table[line] = Line{ new_occurances: 1 }
		} else {
			if table[line].new_occurances == 1 { table[line].new_occurances = 2 } else { table[line].new_occurances = 3 }
		}
		na[i] = table[line]
	}

	for j, line in old {
		if table[line] == Line{} {
			table[line] = Line{ old_occurances: 1 }
		} else {
			if table[line].old_occurances == 0 {
				table[line].old_occurances = 1
			} else if table[line].old_occurances == 1 {
				table[line].old_occurances = 2
			} else {
				table[line].old_occurances = 3
			}
		}
		table[line].old_line_number = j
		oa[j] = table[line]
	}

	for ii, _ in na {
		if na[ii].old_occurances == 1 && na[ii].new_occurances == 1 {
			old_line_number := na[ii].old_line_number
			na[ii] = Line{ actually_other_line_num_ref: true, other_line_num: old_line_number }
			oa[ii] = Line{ actually_other_line_num_ref: true, other_line_num: ii }
		}
	}

	for i, _ in na {
		for j, _ in oa {
			if na[i] == oa[j] && na[i+1] == oa[j+1] {
				oa[j+1] = table[old[i+1]]
				na[i+1] = table[new[j+1]]
			}
		}
	}

	for i, _ in na {
		for j, _ in oa {
			if na[i] == oa[j] && na[i-1] == oa[j-1] {
				oa[j-1] = table[old[i-1]]
				na[i-1] = table[new[j-1]]
			}
		}
	}

	for i, n in na {
		if n.actually_other_line_num_ref { continue }
		key := table.keys()[i]
		line := table[key]
		if line.old_occurances == 0 && line.new_occurances > 0 { println("\e[0;32m + ${key}") }
		if line.old_occurances > 0 && line.new_occurances == 0 { println("\e[0;31m - ${key}") }
		if line.old_occurances > 0 && line.new_occurances > 0 { println("\e[0;33m ~ ${key}‚") }
	}
	println("\e[0m")
}

