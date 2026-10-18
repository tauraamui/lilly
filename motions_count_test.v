// Copyright 2026 The Lilly Edtior contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

module main

import os
import time
import bobatea as tea
import lib.cfg
import lib.documents
import lib.nanoid
import lib.syntax

// a count far past the end of the file, as fuzzing typed: each of these used
// to run every step it asked for, freezing lilly for minutes
const huge_count = '999999999'

// time enough for any of these to reach the end of a small file, and nowhere
// near what a billion steps take
const count_time_limit = 2 * time.second

struct CountTest {
	path   string
	doc_id nanoid.ID
mut:
	c &documents.Controller
	m EditorModel
}

fn count_test(content string) CountTest {
	path := os.join_path(os.temp_dir(), 'lilly_count_${time.now().unix_nano()}.txt')
	os.write_file(path, content) or { panic('failed to write temp file: ${err}') }
	mut c := &documents.Controller{}
	doc_id := c.open_document(path) or { panic('failed to open temp document: ${err}') }
	lang := syntax.resolve_from_extension(path) or { panic(err) }
	mut m := EditorModel{
		config:          EditorWorkspaceConfig.new(cfg.default_config)
		doc_id:          doc_id
		doc_controller:  c
		lang_syn:        lang
		in_focus:        true
		viewport_height: 20
	}
	m.token_parser.set_syntax(lang)
	return CountTest{
		path:   path
		doc_id: doc_id
		c:      c
		m:      m
	}
}

// keys types `keys` in normal mode, and fails the test if they take longer
// than count_time_limit
fn (mut t CountTest) keys(keys string) {
	started := time.now()
	for k in keys.runes() {
		t.m.normal_mode_update(tea.KeyMsg{
			k_type: .runes
			runes:  [k]
		})
	}
	assert time.since(started) < count_time_limit, keys
}

fn (t CountTest) text() string {
	mut out := []string{}
	for y in 0 .. int(t.c.line_count(t.doc_id)) {
		out << (t.c.get_line_bytes(t.doc_id, u64(y)) or { []u8{} }).bytestr()
	}
	return out.join('\n')
}

fn (t CountTest) cursor() (int, int) {
	y, x := t.c.cursor_line_and_x(t.doc_id)
	return int(y), int(x)
}

fn (mut t CountTest) done() {
	os.rm(t.path) or {}
}

fn test_a_huge_count_on_a_motion_stops_where_the_motion_does() {
	for motion, want in {
		'w': [2, 5]
		'e': [2, 8]
		'j': [2, 0]
		'l': [0, 12]
		'}': [2, 0]
	} {
		mut t := count_test('one two three\n\nfour five')
		t.keys(huge_count + motion)
		y, x := t.cursor()
		assert [y, x] == want, motion
		t.done()
	}
}

fn test_a_huge_count_on_a_backward_motion_stops_at_the_start() {
	for motion, want in {
		'b':  [0, 0]
		'{':  [0, 0]
		'ge': [0, 2]
		'k':  [0, 8]
		// h stays on its line, as in Vim
		'h':  [2, 0]
	} {
		mut t := count_test('one two three\n\nfour five')
		t.c.jump_cursor_to_line(t.doc_id, 2)
		t.c.jump_cursor_to_line_end(t.doc_id)
		t.keys(huge_count + motion)
		y, x := t.cursor()
		assert [y, x] == want, motion
		t.done()
	}
}

fn test_a_huge_count_on_x_deletes_to_the_end_of_the_line() {
	mut t := count_test('one two\nthree')
	t.c.move_cursor_right(t.doc_id)
	t.c.move_cursor_right(t.doc_id)
	t.keys(huge_count + 'x')
	assert t.text() == 'on\nthree'
	t.done()
}

fn test_a_huge_count_on_dd_deletes_to_the_end_of_the_file() {
	mut t := count_test('one\ntwo\nthree')
	t.c.move_cursor_down(t.doc_id)
	t.keys(huge_count + 'dd')
	assert t.text() == 'one'
	t.done()
}

fn test_a_count_too_long_for_an_int_is_capped_not_overflowed() {
	mut c := Chord{}
	for ch in '99999999999999999999999'.bytes() {
		c.feed(ch.ascii_str())
	}
	action := c.feed('j') or { panic('a count and a motion make an action') }
	assert action.count == max_count
}
