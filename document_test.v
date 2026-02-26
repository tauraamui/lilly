module documents

/* TEST BLOCK WHICH SHOULD NEVER CHANGE
fn random_function(a int, b int) int {
	return a + b
}
*/

fn test_move_cursor_to_next_word_start() {
	mut ctrl := Controller.new()
	meta_doc_id := ctrl.open_document('document_test.v')!
	for l in ctrl.get_iterator(meta_doc_id) {
		println(l)
	}
	assert false
}

