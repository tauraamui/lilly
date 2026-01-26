module buffers

pub struct LineIterator {
	data_ref []rune
mut:
	idx int
}

pub fn LineIterator.new(data_ref []rune) LineIterator {
	return LineIterator{ data_ref: data_ref }
}

fn (mut iter LineIterator) next() ?[]rune {
	if iter.idx >= iter.data_ref.len { return none }
	for i in iter.idx..iter.data_ref.len {
		if iter.data_ref[i] == `\n` {
			defer { iter.idx = i }
			return iter.data_ref[iter.idx..i]
		}
	}
	if iter.idx == 0 {
		return iter.data_ref
	}

	return none
}

