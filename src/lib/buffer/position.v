module buffer

@[noinit]
pub struct Position {
	PositionFields
}

pub struct PositionArgs {
	PositionFields
}

@[params]
struct PositionFields {
pub:
	line   int
	offset int
}

// pub fn Position.new(line int, offset int) Position {
pub fn Position.new(args PositionArgs) Position {
	line := args.line
	offset := args.offset
	return Position{
		line:   if line < 0 { 0 } else { line }
		offset: if offset < 0 { 0 } else { offset }
	}
}

pub fn (p Position) add(d Distance) Position {
	return Position.new(line: p.line + d.lines, offset: p.offset + d.offset)
}

pub fn (p Position) sub(d Distance) Position {
	return Position.new(line: p.line - d.lines, offset: p.offset - d.offset)
}

pub fn (a Position) distance(b Position) Distance {
	return Distance{
		lines: if a < b { b.line - a.line } else { a.line - b.line }
		offset: if a < b { b.offset - a.offset } else { a.offset - b.offset }
	}
}

pub fn (mut p Position) apply(d Distance) {
	p = p.add(d)
}

const less = true
const greater = false

fn (a Position) < (b Position) bool {
	if a.line < b.line {
		return less
	} else if a.line > b.line {
		return greater
	} else if a.offset < b.offset {
		return less
	} else if a.offset > b.offset {
		return greater
	}
	return greater
}

fn (a Position) == (b Position) bool {
	return a.line == b.line && a.offset == b.offset
}
