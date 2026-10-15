module main

import os
import rand
import time
import lib.documents
import lib.documents.cursor
import lib.cfg
import lib.nanoid
import lib.syntax

const parser_cache_sample = 'fn main() {
	x := "a string" // trailing comment
	/* a block
	   comment */
	y := `raw ` + \'c\'
	if x.len > 0 {
		println(x)
	}
}
'

// the snippets random inserts draw from: mostly ones that open or close
// parser states, so edits keep changing how the lines below them lex
const parser_cache_snippets = ['/*', '*/', '"', "'", '`', '//', '\n', 'abc', ' ', '\n/* x\n', '"\n"',
	'{', '}', '\${', '"\${x', '\\']

fn make_parser_cache_test_file(content string) string {
	path := os.join_path(os.temp_dir(), 'lilly_parser_cache_${time.now().unix_nano()}')
	os.write_file(path, content) or { panic('failed to write temp file: ${err}') }
	return path
}

fn new_parser_cache_test_editor(c &documents.Controller2, doc_id nanoid.ID) EditorModel2 {
	v_syntax := syntax.resolve_from_extension('main.v') or { panic(err) }
	mut m := EditorModel2{
		config:         EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:         doc_id
		doc_controller: c
		lang_syn:       v_syntax
	}
	m.token_parser.set_syntax(v_syntax)
	return m
}

// state_names describes an editor's cached line states by their context
// stacks, which unlike the states themselves compare between editors
fn state_names(m EditorModel2) []string {
	return m.parser_line_states.map(m.token_parser.state_name(it))
}

// expected_parser_states is what lexing the whole document from scratch
// gives, as it stands
fn expected_parser_states(c &documents.Controller2, doc_id nanoid.ID) []string {
	mut fresh := new_parser_cache_test_editor(c, doc_id)
	fresh.ensure_parser_states(int(c.line_count(doc_id)) - 1)
	return state_names(fresh)
}

// view_down_to extends an editor's states as far as a viewport whose top is
// at a random line would, and checks the states it holds against `expected`
fn view_down_to(mut rng rand.PRNG, mut m EditorModel2, expected []string, label string) {
	m.ensure_parser_states(rng.intn(expected.len + 1) or { 0 })
	held := state_names(m)
	assert held.len <= expected.len, label
	assert held == expected[..held.len], label
}

fn random_parser_cache_edit(mut rng rand.PRNG, mut c documents.Controller2, doc_id nanoid.ID) {
	line_count := int(c.line_count(doc_id))
	c.jump_cursor_to_line(doc_id, u64(rng.intn(line_count) or { 0 }))
	for _ in 0 .. rng.intn(6) or { 0 } {
		c.move_cursor_right(doc_id)
	}
	match rng.intn(9) or { 0 } {
		0, 1, 2 {
			c.insert_string(doc_id, rng.element(parser_cache_snippets) or { '' })
		}
		3 {
			c.backspace(doc_id)
		}
		4 {
			c.delete(doc_id)
		}
		5 {
			y := u64(rng.intn(line_count) or { 0 })
			c.delete_line(doc_id, y)
		}
		6 {
			start_y := rng.intn(line_count) or { 0 }
			end_y := start_y + (rng.intn(3) or { 0 })
			c.delete_range(doc_id, cursor.Range{
				start: cursor.Pos.new(rng.intn(4) or { 0 }, start_y)
				end:   cursor.Pos.new(rng.intn(6) or { 0 }, end_y)
			})
		}
		7 {
			c.undo(doc_id)
		}
		else {
			c.redo(doc_id)
		}
	}
	if rng.intn(3) or { 0 } == 0 {
		c.commit_undo_group(doc_id)
	}
}

fn test_parser_state_cache_matches_full_rebuild_across_random_edits() {
	file_path := make_parser_cache_test_file(parser_cache_sample)
	defer { os.rm(file_path) or {} }

	// a generator of its own, not rand's shared one: opening a document
	// reseeds that from the file's path (its ID is nanoid.simple_with_seed),
	// and the temp path holds a timestamp, so the edits differed every run
	mut rng := rand.new_default(seed_: [u32(750), 1])
	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }

	// one editor syncs after every edit, the other (a split on the same
	// document) only now and then, so it catches up across several at once
	mut every_edit := new_parser_cache_test_editor(&c, doc_id)
	mut now_and_then := new_parser_cache_test_editor(&c, doc_id)
	every_edit.sync_parser_state_cache()
	now_and_then.sync_parser_state_cache()

	mut deepest := 0
	for i in 0 .. 500 {
		random_parser_cache_edit(mut rng, mut c, doc_id)
		expected := expected_parser_states(&c, doc_id)
		for name in expected {
			deepest = int_max(deepest, name.count(' > ') + 1)
		}

		// driven by hand rather than through sync_parser_state_cache, so a
		// relex that quietly falls back to a full rebuild fails the test
		changes := c.line_changes_since(doc_id, every_edit.parser_gen)
		every_edit.parser_gen = changes.gen
		assert changes.complete, 'after edit ${i}'
		if changes.changed {
			assert every_edit.relex_parser_state_cache(changes.change.first, changes.change.last,
				changes.change.delta), 'after edit ${i}'
		}
		view_down_to(mut rng, mut every_edit, expected, 'after edit ${i}')

		if rng.intn(5) or { 0 } == 0 {
			now_and_then.sync_parser_state_cache()
			view_down_to(mut rng, mut now_and_then, expected, 'after edit ${i}')
		}
	}
	// stacks over two deep are interned rather than encoded, so the edits
	// have to reach them for this test to cover interning. About one seed in
	// ten never does; this one reaches five deep.
	assert deepest >= 3
}

fn test_parser_state_cache_trimmed_past_the_view_matches_full_rebuild() {
	// long enough that a relex can reach past the view and its slack, where
	// it lets the states go for background lexing to redo
	file_path := make_parser_cache_test_file(parser_cache_sample.repeat(80))
	defer { os.rm(file_path) or {} }

	mut rng := rand.new_default(seed_: [u32(739), 5])
	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut m := new_parser_cache_test_editor(&c, doc_id)
	m.viewport_height = 10
	m.sync_parser_state_cache()

	mut trimmed := 0
	for i in 0 .. 300 {
		// the view anywhere, and every state held, so an edit above it relexes
		// down to the view's limit and no further
		line_count := int(c.line_count(doc_id))
		m.top_line = rng.intn(line_count) or { 0 }
		m.ensure_parser_states(line_count - 1)
		random_parser_cache_edit(mut rng, mut c, doc_id)
		expected := expected_parser_states(&c, doc_id)

		changes := c.line_changes_since(doc_id, m.parser_gen)
		m.parser_gen = changes.gen
		assert changes.complete, 'after edit ${i}'
		if changes.changed {
			assert m.relex_parser_state_cache(changes.change.first, changes.change.last,
				changes.change.delta), 'after edit ${i}'
		}
		if m.parser_line_states.len == m.top_line + m.viewport_height + relex_slack + 1 {
			trimmed++
		}
		view_down_to(mut rng, mut m, expected, 'after edit ${i}')
	}
	assert trimmed > 0, 'no relex reached the limit'
}

fn test_parser_state_cache_relexes_one_line_for_a_plain_edit() {
	file_path := make_parser_cache_test_file(parser_cache_sample)
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut m := new_parser_cache_test_editor(&c, doc_id)
	m.sync_parser_state_cache()
	m.ensure_parser_states(int(c.line_count(doc_id)) - 1)

	// a plain character on the first line changes nothing below it, so the
	// relex must stop straight after that line
	c.insert_rune(doc_id, `z`)
	changes := c.line_changes_since(doc_id, m.parser_gen)
	assert changes.complete
	assert changes.change.first == 0
	assert changes.change.last == 0
	assert changes.change.delta == 0

	m.sync_parser_state_cache()
	assert state_names(m) == expected_parser_states(&c, doc_id)

	// nothing new since the last sync
	assert !c.line_changes_since(doc_id, m.parser_gen).changed
}

fn test_parser_state_cache_opening_a_block_comment_reaches_lines_below() {
	file_path := make_parser_cache_test_file('a\nb\nc\nd\n')
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut m := new_parser_cache_test_editor(&c, doc_id)
	m.sync_parser_state_cache()
	m.ensure_parser_states(4)
	assert state_names(m) == ['main', 'main', 'main', 'main', 'main']

	c.insert_string(doc_id, '/*')
	m.sync_parser_state_cache()
	m.ensure_parser_states(4)
	assert state_names(m) == expected_parser_states(&c, doc_id)
	assert m.token_parser.state_name(m.parser_line_states[3]) == 'main > block_comment'
}

fn test_parser_states_are_only_lexed_down_to_the_line_asked_for() {
	file_path := make_parser_cache_test_file('a\n'.repeat(1000))
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut m := new_parser_cache_test_editor(&c, doc_id)
	m.sync_parser_state_cache()
	m.ensure_parser_states(10)
	assert m.parser_line_states.len == 11

	// an edit below what's held changes nothing; one inside it keeps what's
	// above the edit
	c.jump_cursor_to_line(doc_id, 500)
	c.insert_string(doc_id, '/*')
	m.sync_parser_state_cache()
	assert m.parser_line_states.len == 11
	c.jump_cursor_to_line(doc_id, 5)
	c.insert_string(doc_id, '\n\n')
	m.sync_parser_state_cache()
	assert m.parser_line_states.len == 13
	assert state_names(m) == expected_parser_states(&c, doc_id)[..13]
}

fn node_names(nodes []syntax.Node) []string {
	return nodes.map('${it.name}@${it.start.line}:${it.start.col}')
}

fn test_syntax_tree_matches_a_fresh_tree_across_random_edits() {
	// long enough that edits land on both sides of tree checkpoints
	file_path := make_parser_cache_test_file(parser_cache_sample.repeat(60))
	defer { os.rm(file_path) or {} }

	mut rng := rand.new_default(seed_: [u32(737), 3])
	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut m := new_parser_cache_test_editor(&c, doc_id)

	mut deepest := 0
	for i in 0 .. 300 {
		random_parser_cache_edit(mut rng, mut c, doc_id)
		// sometimes several edits go by between queries
		if rng.intn(3) or { 0 } == 0 {
			continue
		}
		mut fresh := new_parser_cache_test_editor(&c, doc_id)
		line_count := int(c.line_count(doc_id))
		for _ in 0 .. 3 {
			y := rng.intn(line_count) or { 0 }
			line_len := (c.get_line_bytes(doc_id, u64(y)) or { []u8{} }).bytestr().runes().len
			pos := syntax.Pos{y, rng.intn(line_len + 1) or { 0 }}
			got := m.syntax_ancestors(pos)
			deepest = int_max(deepest, got.len)
			assert node_names(got) == node_names(fresh.syntax_ancestors(pos)), 'after edit ${i}'
		}
	}
	assert deepest >= 3
}

fn test_syntax_find_finds_calls_by_scope() {
	file_path := make_parser_cache_test_file(parser_cache_sample)
	defer { os.rm(file_path) or {} }

	mut c := documents.Controller2{}
	doc_id := c.open_document(file_path) or { panic('failed to open temp document: ${err}') }
	mut m := new_parser_cache_test_editor(&c, doc_id)
	last := int(c.line_count(doc_id)) - 1

	assert m.syntax_find('println', [], 0, last).map(it.pos) == [syntax.Pos{6, 2}]
	assert m.syntax_find('x', [.variable], 0, last).map(it.pos.line) == [5, 6]
	// where it's declared is a definition, as main is where it's defined
	assert m.syntax_find('x', [.variable_definition], 0, last).map(it.pos.line) == [1]
	assert m.syntax_find('main', [.function_definition], 0, last).map(it.pos) == [
		syntax.Pos{0, 3},
	]

	// the tree follows an edit. (Typing a bracket would auto close it.)
	c.insert_string(doc_id, 'println\n')
	assert m.syntax_find('println', [], 0, last + 1).map(it.pos) == [syntax.Pos{0, 0},
		syntax.Pos{7, 2}]
	body := m.syntax_ancestors(syntax.Pos{7, 2})
	assert node_names(body) == ['function@1:0', '{}@1:10', '{}@6:14']
}

fn test_expand_tab_runes_matches_expand_tabs() {
	mut out := []rune{}
	for line in ['', 'no tabs', '\tlead', 'mid\tdle\t', '\t\t'] {
		for width in [0, 1, 4] {
			assert expand_tab_runes(line.runes(), width, mut out) == expand_tabs(line.bytes(),
				width).runes(), '${line} ${width}'
		}
	}
	// a line without tabs is given back as it is
	plain := 'x := 1'.runes()
	out.clear()
	assert expand_tab_runes(plain, 4, mut out) == plain
	assert out.len == 0
}
