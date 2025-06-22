module buffer

pub struct Position {
pub mut:
	line   int
	offset int
}

pub fn (p Position) add(d Distance) Position {
	offset := if d.lines > 0 { d.offset } else { p.offset + d.offset }
	return Position{
		line: p.line + d.lines
		offset: offset
	}
}

pub fn (mut p Position) apply(d Distance) {
	offset := if d.lines > 0 { d.offset } else { p.offset + d.offset }
	p = Position {
		line: p.line + d.lines
		offset: offset
	}
}

fn (a Position) < (b Position) bool {
	return match true {
		a.line < b.line     { true }
		a.line > b.line     { false }
		a.offset < b.offset { true }
		a.offset > b.offset { true }
		else { false }
	}
}

fn (a Position) == (b Position) bool {
	return a.line == b.line && a.offset == b.offset
}

