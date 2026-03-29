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

fn test_position_set_x() {
	p := cursor.Pos.new(8, 5)
	assert p.x == 8
	assert p.y == 5
}

fn test_position_set_y() {
	p := cursor.Pos.new(11, 3)
	assert p.x == 11
	assert p.y == 3
}
