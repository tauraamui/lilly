module main

import tauraamui.bobatea as tea
import documents

fn test_cursor_up_moves_up() {
	mut cursor := ModelCursorPos{}
	assert cursor.x == 0
	assert cursor.y == 0

	cursor = cursor.left()
	assert cursor.x == 0
	assert cursor.y == 0

	cursor = cursor.down(max_height: 100)
	assert cursor.x == 0
	assert cursor.y == 1

	cursor = cursor.up()
	assert cursor.x == 0
	assert cursor.y == 0

	cursor = cursor.right(max_width: 100)
	assert cursor.x == 1
	assert cursor.y == 0

	cursor = cursor.down(max_height: 100)
	assert cursor.x == 0
	assert cursor.y == 1

	cursor = cursor.right(distance: 99, max_width: 100)
	assert cursor.x == 99
	assert cursor.y == 1
}
