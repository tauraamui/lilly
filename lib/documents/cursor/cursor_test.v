module cursor_test

import lib.documents.cursor

fn test_position_equality_ignores_largest_x() {
	a_pos := cursor.Pos.new(10, 10)
	b_pos := cursor.Pos.new(10, 10)
	assert a_pos == b_pos
}
