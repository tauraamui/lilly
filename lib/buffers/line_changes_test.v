module buffers

fn test_then_widens_to_cover_both_changes() {
	// edit line 2, then edit line 7: one change spanning both
	merged := LineChange{2, 2, 0}.then(LineChange{7, 7, 0})
	assert merged == LineChange{2, 7, 0}
}

fn test_then_moves_the_earlier_change_with_lines_inserted_above_it() {
	// edit line 5, then insert two lines at line 1: line 5 is now line 7
	merged := LineChange{5, 5, 0}.then(LineChange{1, 3, 2})
	assert merged == LineChange{1, 7, 2}
}

fn test_then_keeps_an_earlier_change_above_the_later_one_in_place() {
	// split line 1 into two, then edit line 9
	merged := LineChange{1, 2, 1}.then(LineChange{9, 9, 0})
	assert merged == LineChange{1, 9, 1}
}

fn test_then_never_ends_before_it_starts() {
	// join lines 4..6 into line 4, then delete into line 3
	merged := LineChange{4, 4, -2}.then(LineChange{3, 3, -1})
	assert merged.first == 3
	assert merged.last >= merged.first
	assert merged.delta == -3
}

fn test_log_folds_edits_between_reads_into_one_entry() {
	mut log := LineChangeLog{}
	start := log.since(0).gen
	log.add(LineChange{3, 3, 0})
	log.add(LineChange{3, 4, 1})
	assert log.entries.len == 1

	changes := log.since(start)
	assert changes.changed
	assert changes.complete
	assert changes.change == LineChange{3, 4, 1}

	// that read sealed the entry, so the next edit gets its own
	log.add(LineChange{0, 0, 0})
	assert log.entries.len == 2
	assert log.since(changes.gen).change == LineChange{0, 0, 0}
}

fn test_log_tells_a_reader_that_never_read_to_rebuild() {
	mut log := LineChangeLog{}
	first := log.since(0)
	assert first.changed
	assert !first.complete
	assert first.gen != 0

	assert !log.since(first.gen).changed
}

fn test_log_tells_a_reader_that_fell_behind_to_rebuild() {
	mut log := LineChangeLog{}
	behind := log.since(0).gen
	for i in 0 .. line_change_log_cap + 1 {
		log.add(LineChange{i, i, 0})
		log.sealed = true // as if another reader looked after every edit
	}
	assert log.entries.len == line_change_log_cap
	changes := log.since(behind)
	assert changes.changed
	assert !changes.complete
}

fn test_text_buffer_reports_lines_an_undo_touched() {
	mut tb := TextBuffer{}
	tb.history.recording = true
	for c in 'one\ntwo\nthree'.bytes() {
		tb.insert_byte(c)
	}
	tb.commit_undo_group()
	gen := tb.line_changes_since(0).gen

	tb.undo()
	changes := tb.line_changes_since(gen)
	assert changes.complete
	assert changes.change.first == 0
	assert changes.change.delta == -2
	assert tb.line_count() == 1
}
