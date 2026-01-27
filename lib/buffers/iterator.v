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
		defer { iter.idx = i + 1 }

		if iter.data_ref[i] == `\n` {
			return iter.data_ref[iter.idx..i]
		}
	}

	// no newline was found at all, return all data
	if iter.idx == 0 {
		return iter.data_ref
	}

	// between the last found newline and end of the data
	return iter.data_ref[iter.idx..]
}

