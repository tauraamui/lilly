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
	for i in iter.idx..iter.data_ref.len {
		if iter.data_ref[i] == `\n` {
			defer { iter.idx = i + 1 }
			return iter.data_ref[iter.idx..i]
		}
	}

	if iter.idx == 0 {
		return iter.data_ref
	}

	if iter.idx > 0 {
		return iter.data_ref[iter.idx..]
	}

	return none
}

