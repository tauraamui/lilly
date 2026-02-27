module documents_test

/* TEST BLOCK WHICH SHOULD NEVER CHANGE
// This is a fake test comment for verifying word jumping
fn random_function(a int, b int) int {
	return a + b
}
*/

import documents
import petal

fn test_move_cursor_to_next_word_start() {
	mut ctrl := documents.Controller.new()
	meta_doc_id := ctrl.open_document('document_test.v')!

	ctrl.move_cursor_up(meta_doc_id, .normal)
	ctrl.move_cursor_up(meta_doc_id, .normal)
	ctrl.move_cursor_up(meta_doc_id, .normal)

	ctrl.move_cursor_right(meta_doc_id, .normal)
	ctrl.move_cursor_right(meta_doc_id, .normal)
	ctrl.move_cursor_right(meta_doc_id, .normal)

	// assert 'fn random_function(a int, b int) int {' == ctrl.get_line_at(meta_doc_id, ctrl.cursor_pos(meta_doc_id).y)?
	ctrl.move_cursor_to_next_word_start(meta_doc_id)
	assert false
}

