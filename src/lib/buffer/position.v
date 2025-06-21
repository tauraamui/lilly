module buffer

pub struct Position {
pub:
	line   int
	offset int
}

pub fn Position.new() Position {
	return Position{ line: 0, offset: 0 }
}

pub fn (p Position) add(d Distance) Position {
	offset := if d.lines > 0 { d.offset } else { p.offset + d.offset }
	return Position{
		line: p.line + d.lines
		offset: offset
	}
}

