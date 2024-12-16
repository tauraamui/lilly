module main

import log
import lib.clipboardv2
import lib.buffer

fn test_insert_text() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("1. first line\n2. second line")

	fake_view.insert_text("Random words!")

	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"Random words!1. first line",
		"2. second line"
	]
}

fn test_o_inserts_empty_line() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("1. first line\n2. second line")

	fake_view.o()

	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"1. first line",
		""
		"2. second line"
	]
	assert fake_view.buffer.cursor.y == 1
}
