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
