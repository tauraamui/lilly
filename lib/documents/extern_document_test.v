// Copyright 2026 The Lilly Edtior contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

module documents_test

/* TEST BLOCK WHICH SHOULD NEVER CHANGE
// This is a fake test comment for verifying word jumping
fn random_function(a int, b int) int {

	y_sum := a * a


	x_sum := b * b
	defer {

	}
	return y_sum + x_sum
}

fn second_random_function() {
	a.thing = 9
}

fn third_random_function() {
	mut ctrl := documents.Controller.new()
	meta_doc_id := ctrl.open_document('extern_document_test.v')!
}
*/
import encoding.utf8
import documents
import documents.cursor

fn test_move_cursor_to_next_word_start() {
	mut ctrl := documents.Controller.new()
	meta_doc_id := ctrl.open_document('./lib/documents/extern_document_test.v')!

	mut pos := cursor.Pos.new(0, 0)
	for _ in 0 .. 17 {
		pos = ctrl.move_cursor_down(meta_doc_id, pos, .normal)
	}

	pos = ctrl.move_cursor_right(meta_doc_id, pos, .normal)
	pos = ctrl.move_cursor_right(meta_doc_id, pos, .normal)
	pos = ctrl.move_cursor_right(meta_doc_id, pos, .normal)

	mut current_line := ctrl.get_line_at(meta_doc_id, pos.y) or {
		panic('failed to aquire current line')
	}

	// first set: line 3 (// This is a ...) through line 4 (fn random_function...)
	// no empty lines crossed, no multi-char punct groups — expectations unchanged
	mut word_start_chars := ['i', 'a', 'f', 't', 'c', 'f', 'v', 'w', 'j', 'f', 'r', '(', 'a', 'i',
		',', 'b', 'i', ')', 'i', '{']
	for c in word_start_chars {
		pos = ctrl.move_cursor_to_next_word_start(meta_doc_id, pos)
		current_line = ctrl.get_line_at(meta_doc_id, pos.y) or {
			panic('failed to aquire current line')
		}
		assert '${current_line.runes()[pos.x]}' == c
	}

	pos = ctrl.move_cursor_down(meta_doc_id, pos, .normal)
	pos = ctrl.move_cursor_down(meta_doc_id, pos, .normal)
	pos = ctrl.move_cursor_down(meta_doc_id, pos, .normal)

	// second set: navigates through lines with empty lines and merged punct/symbol classes
	// empty lines are now stop points (Vim-compatible), := and () are single words
	// '' marks an empty line stop
	word_start_chars = [
		'', // empty line 8
		'x',
		':',
		'b',
		'*',
		'b', // \tx_sum := b * b
		'd',
		'{', // \tdefer {
		'', // empty line 11
		'}', // \t}
		'r',
		'y',
		'+',
		'x', // \treturn y_sum + x_sum
		'}', // }
		'', // empty line 15
		'f',
		's',
		'(',
		'{', // fn second_random_function() {
		'a',
		'.',
		't',
		'=',
		'9', // \ta.thing = 9
		'}', // }
		'', // empty line 19
		'f',
		't',
		'(',
		'{', // fn third_random_function() {
		'm',
		'c',
		':',
		'd',
		'.',
		'C',
		'.',
		'n',
		'(', // \tmut ctrl := documents.Controller.new()
	]

	for i, c in word_start_chars {
		pos = ctrl.move_cursor_to_next_word_start(meta_doc_id, pos)
		current_line = ctrl.get_line_at(meta_doc_id, pos.y) or {
			panic('failed to aquire current line')
		}
		if c == '' {
			// empty line stop — cursor should be at x=0 on an empty line
			assert '[${i}] expected empty line stop' == '[${i}] expected empty line stop'
			assert current_line.len == 0
		} else {
			assert '[${i}]${current_line.runes()[pos.x]}' == '[${i}]${c}'
		}
	}
}

fn test_utf8_emoji_classification() {
	emoji := '${[u8(0xf0), 0x9f, 0x92, 0x95].bytestr()}'
	assert utf8.is_space(emoji.runes()[0]) == false
	assert utf8.is_rune_punct(emoji.runes()[0]) == false

	// all non-keyword non-whitespace characters resolve to .other
	assert documents.CharType.resolve(':'.runes()[0]) == .other
	assert documents.CharType.resolve('='.runes()[0]) == .other
	assert documents.CharType.resolve('('.runes()[0]) == .other
	assert documents.CharType.resolve(')'.runes()[0]) == .other
	assert documents.CharType.resolve('{'.runes()[0]) == .other

	// keyword characters resolve to .alpha_num
	assert documents.CharType.resolve('_'.runes()[0]) == .alpha_num
	assert documents.CharType.resolve('a'.runes()[0]) == .alpha_num
	assert documents.CharType.resolve('0'.runes()[0]) == .alpha_num

	// whitespace resolves to .whitespace
	assert documents.CharType.resolve(' '.runes()[0]) == .whitespace

	// emoji resolves to .other (non-keyword non-whitespace)
	assert documents.CharType.resolve(emoji.runes()[0]) == .other
}
