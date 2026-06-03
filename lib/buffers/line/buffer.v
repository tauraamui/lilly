module line

@[noinit]
pub struct Buffer {
pub mut:
	offsets      []u64
	current_line u64
}

pub fn Buffer.new() Buffer {
	return Buffer{
		offsets:      []u64{ len: 1, cap: 1 }
		current_line: 0
	}
}


