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

fn test_shift_o_inserts_empty_line_above_current() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("1. first line\n2. second line\n3. third line")

	fake_view.cursor.pos.y = 1

	fake_view.shift_o()

	assert fake_view.leader_state.mode == .insert
	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"1. first line"
		""
		"2. second line"
		"3. third line"
	]
	assert fake_view.cursor.pos.y == 1
}

fn test_shift_o_inserts_empty_line_above_current_first_line_of_document() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("1. first line\n2. second line\n3. third line")

	fake_view.cursor.pos.y = 0

	fake_view.shift_o()

	assert fake_view.leader_state.mode == .insert
	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		""
		"1. first line"
		"2. second line"
		"3. third line"
	]
	assert fake_view.cursor.pos.y == 0
}

fn test_o_inserts_empty_line_below_current() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("1. first line\n2. second line\n3. third line")

	fake_view.cursor.pos.y = 1

	fake_view.o()

	assert fake_view.leader_state.mode == .insert
	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"1. first line"
		"2. second line"
		""
		"3. third line"
	]
	assert fake_view.cursor.pos.y == 2
}

fn test_o_inserts_empty_line_below_current_last_line_of_document() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("1. first line\n2. second line\n3. third line")

	fake_view.cursor.pos.y = 2

	fake_view.o()

	assert fake_view.leader_state.mode == .insert
	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"1. first line"
		"2. second line"
		"3. third line"
		""
	]
	assert fake_view.cursor.pos.y == 3
}

fn test_x_removes_characters_on_single_line_document() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("This is a single line document that happens to be quite long.")

	fake_view.cursor.pos.x = 20
	fake_view.x()
	fake_view.x()
	fake_view.x()
	fake_view.x()

	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"This is a single lincument that happens to be quite long."
	]
	assert fake_view.cursor.pos.y == 0
}

fn test_x_does_not_remove_characters_on_multi_line_document_if_at_line_end() {
	mut clip := clipboardv2.new()
	mut fake_view := View{
		log: log.Log{}
		leader_state: ViewLeaderState{ mode: .normal }
		clipboard: mut clip
	}

	fake_view.buffer.use_gap_buffer = true
	// manually set the "document" contents
	fake_view.buffer.load_contents_into_gap("1. first line\n2. second line\n3. third line")

	fake_view.cursor.pos.x = fake_view.buffer.find_end_of_line(buffer.Pos{ y: fake_view.cursor.pos.y }) or { 0 }
	fake_view.x()

	lines := fake_view.buffer.str().split("\n")
	assert lines == [
		"1. first line"
		"2. second line"
		"3. third line"
	]
	assert fake_view.cursor.pos.y == 0
}

