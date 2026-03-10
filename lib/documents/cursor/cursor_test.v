module cursor_test

import lib.documents.cursor

fn test_position_equality_ignores_largest_x() {
	a_pos := cursor.Pos.new(10, 10)
	b_pos := cursor.Pos.new(10, 10)
	assert a_pos == b_pos

	x_pos := cursor.Pos.new(1, 2).x(120).x(9)
	y_pos := cursor.Pos.new(1, 2).x(3).x(9)
	assert x_pos == y_pos
}
