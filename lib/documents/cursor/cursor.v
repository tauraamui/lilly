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

module cursor

@[noinit]
pub struct Pos {
pub:
	largest_x int // used to track largest x set across struct instance lifetime
	x int
	y int
}

pub fn Pos.new(x int, y int) Pos {
	return Pos{ x: x, y: y, largest_x: x }
}

pub fn Pos.new_z(x int, y int, z int) Pos {
	return Pos{ x: x, y: y, largest_x: z }
}

fn (a Pos) == (b Pos) bool {
	return a.x == b.x && a.y == b.y
}

pub fn (p Pos) x(x int) Pos {
	xx := if x < 0 { 0 } else { x }
	return Pos{
		x: xx
		y: p.y
		largest_x: if xx > p.largest_x { xx } else { p.largest_x }
	}
}

pub fn (p Pos) y(y int) Pos {
	return Pos{
		x: p.x
		y: y
		largest_x: p.largest_x
	}
}

pub struct Range {
pub:
	start Pos
	end   Pos
}
