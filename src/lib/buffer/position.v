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
