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
*/

import encoding.utf8
import documents
import petal

fn test_move_cursor_to_next_word_start() {
	mut ctrl := documents.Controller.new()
	meta_doc_id := ctrl.open_document('extern_document_test.v')!

	ctrl.move_cursor_down(meta_doc_id, .normal)
	ctrl.move_cursor_down(meta_doc_id, .normal)
	ctrl.move_cursor_down(meta_doc_id, .normal)

	ctrl.move_cursor_right(meta_doc_id, .normal)
	ctrl.move_cursor_right(meta_doc_id, .normal)
	ctrl.move_cursor_right(meta_doc_id, .normal)

	mut current_line := ctrl.get_line_at(meta_doc_id, ctrl.cursor_pos(meta_doc_id).y) or { panic('failed to aquire current line') }

	mut word_start_chars := ['i', 'a', 'f', 't', 'c', 'f', 'v', 'w', 'j']
	for c in word_start_chars {
		ctrl.move_cursor_to_next_word_start(meta_doc_id)
		assert '${current_line.runes()[ctrl.cursor_pos(meta_doc_id).x]}' == c
	}

	ctrl.move_cursor_to_next_word_start(meta_doc_id)
	current_line = ctrl.get_line_at(meta_doc_id, ctrl.cursor_pos(meta_doc_id).y) or { panic('failed to aquire current line') }
	assert '${current_line.runes()[ctrl.cursor_pos(meta_doc_id).x]}' == 'f'

	ctrl.move_cursor_to_next_word_start(meta_doc_id)
	current_line = ctrl.get_line_at(meta_doc_id, ctrl.cursor_pos(meta_doc_id).y) or { panic('failed to aquire current line') }
	assert '${current_line.runes()[ctrl.cursor_pos(meta_doc_id).x]}' == 'r'

	ctrl.move_cursor_down(meta_doc_id, .normal)
	ctrl.move_cursor_down(meta_doc_id, .normal)
	ctrl.move_cursor_down(meta_doc_id, .normal)

	word_start_chars = ['x', ':', 'b', '*', 'b', 'd', '{', '}', 'r', 'y', '+', 'x', '}']
	for i, c in word_start_chars {
		ctrl.move_cursor_to_next_word_start(meta_doc_id)
		current_line = ctrl.get_line_at(meta_doc_id, ctrl.cursor_pos(meta_doc_id).y) or { panic('failed to aquire current line') }
		assert '[${i}]${current_line.runes()[ctrl.cursor_pos(meta_doc_id).x]}' == '[${i}]${c}'
	}

	word_start_chars = ['f', 's', '(', ')', '{', 'a', '.', 't', '=', '9', '}']
	for i, c in word_start_chars {
		ctrl.move_cursor_to_next_word_start(meta_doc_id)
		current_line = ctrl.get_line_at(meta_doc_id, ctrl.cursor_pos(meta_doc_id).y) or { panic('failed to aquire current line') }
		assert '[${i}]${current_line.runes()[ctrl.cursor_pos(meta_doc_id).x]}' == '[${i}]${c}'
	}
}

fn test_move_cursor_to_next_word_start_punctuation_and_quotes() {
}

fn test_utf8_emoji_classification() {
	emoji := '${[u8(0xf0), 0x9f, 0x92, 0x95].bytestr()}'
	assert utf8.is_space(emoji.runes()[0])      == false
	assert utf8.is_rune_punct(emoji.runes()[0]) == false

	assert documents.is_punct(':'.runes()[0])
	assert documents.is_punct('='.runes()[0]) == false
	assert documents.is_punct('_'.runes()[0]) == false
	assert documents.is_punct('('.runes()[0]) == false


	assert documents.is_symbol(':'.runes()[0]) == false
	assert documents.is_symbol('='.runes()[0])
	assert documents.is_symbol('_'.runes()[0]) == false
	assert documents.is_symbol('('.runes()[0])
}

