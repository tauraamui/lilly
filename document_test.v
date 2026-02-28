module documents_test

/* TEST BLOCK WHICH SHOULD NEVER CHANGE
// This is a fake test comment for verifying word jumping
fn random_function(a int, b int) int {
	a_sum := a * a


	b_sum := b * b
	return a_sum + b_sum
}
*/

import documents
import petal

fn test_move_cursor_to_next_word_start() {
	mut ctrl := documents.Controller.new()
	meta_doc_id := ctrl.open_document('document_test.v')!

	ctrl.move_cursor_down(meta_doc_id, .normal)
	ctrl.move_cursor_down(meta_doc_id, .normal)
	ctrl.move_cursor_down(meta_doc_id, .normal)

	ctrl.move_cursor_right(meta_doc_id, .normal)
	ctrl.move_cursor_right(meta_doc_id, .normal)
	ctrl.move_cursor_right(meta_doc_id, .normal)

	mut current_line := ctrl.get_line_at(meta_doc_id, ctrl.cursor_pos(meta_doc_id).y) or { panic('failed to aquire current line') }

	word_start_chars := ['i', 'a', 'f', 't', 'c', 'f', 'v', 'w', 'j']
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

	ctrl.move_cursor_to_next_word_start(meta_doc_id)
	current_line = ctrl.get_line_at(meta_doc_id, ctrl.cursor_pos(meta_doc_id).y) or { panic('failed to aquire current line') }
	assert '${current_line.runes()[ctrl.cursor_pos(meta_doc_id).x]}' == 'b'

	ctrl.move_cursor_to_next_word_start(meta_doc_id)
	current_line = ctrl.get_line_at(meta_doc_id, ctrl.cursor_pos(meta_doc_id).y) or { panic('failed to aquire current line') }
	assert '${current_line.runes()[ctrl.cursor_pos(meta_doc_id).x]}' == ':'
}

