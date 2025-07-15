module buffer

pub struct Distance {
pub:
	lines  int
	offset int
}

pub fn Distance.of_str(from string) Distance {
	return Distance{
		lines:  from.runes().count(it == lf)
		offset: from.split([lf].string()).last().len
	}
}
