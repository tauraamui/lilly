module line

pub struct Buffer {
mut:
	offsets      []u64
	current_line int
}

pub fn Buffer.new() Buffer {
	return Buffer{
		// lines: []int{ len: 1, cap: 1 }
	}
}

pub fn (mut lb Buffer) increment() {
	// lb.lines[0] += 1
}

