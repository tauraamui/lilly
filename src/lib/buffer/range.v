module buffer

@[noinit]
pub struct Range {
pub:
	start Position
	end   Position
}

pub fn Range.new(start Position, end Position) Range {
	if start > end {
		return Range{
			start: end
			end:   start
		}
	}
	return Range{start, end}
}

pub fn (range Range) includes(position Position) bool {
	return position >= range.start && position < range.end
}
