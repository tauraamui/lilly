module buffer

@[noinit]
pub struct Position {
pub:
	line   int
	offset int
}

pub fn Position.new(line int, offset int) Position {
	return Position{
		line:   if line < 0 { 0 } else { line }
		offset: if offset < 0 { 0 } else { offset }
	}
}

pub fn (p Position) add(d Distance) Position {
	// offset := if d.lines > 0 { d.offset } else { p.offset + d.offset }
	offset := p.offset + d.offset
	line := p.line + d.lines

	return Position{
		line:   if line < 0 { 0 } else { line }
		offset: if offset < 0 { 0 } else { offset }
	}
}

pub fn (mut p Position) apply(d Distance) {
	p = p.add(d)
}

fn (a Position) < (b Position) bool {
	return match true {
		a.line < b.line { true }
		a.line > b.line { false }
		a.offset < b.offset { true }
		a.offset > b.offset { true }
		else { false }
	}
}

fn (a Position) == (b Position) bool {
	return a.line == b.line && a.offset == b.offset
}
