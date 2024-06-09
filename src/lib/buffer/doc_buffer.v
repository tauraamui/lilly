module buffer

pub struct Document {
pub:
	file_path string
mut:
	data map[int]GapBuffer
}

struct GapBuffer {
mut:
	line []rune
}

fn GapBuffer.new() &GapBuffer {
}

fn (mut gap_buffer GapBuffer)
