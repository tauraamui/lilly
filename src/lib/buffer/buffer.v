module buffer

pub struct Buffer {
pub:
	file_path string
pub mut:
	lines            []string
	auto_close_chars []string
mut:
	use_gap_buffer   bool
	c_buffer         GapBuffer
	// line_tracker LineTracker
}

pub fn (mut buffer Buffer) load_from_path(read_lines fn (path string) ![]string, use_gap_buffer bool) ! {
	buffer.lines = read_lines(buffer.file_path) or {
		return error('unable to open file ${buffer.file_path} ${err}')
	}
	if buffer.lines.len == 0 {
		buffer.lines = ['']
	}

	if use_gap_buffer {
		buffer.use_gap_buffer = use_gap_buffer
		file_contents := buffer.lines.join("\n")
		buffer.c_buffer = GapBuffer.new(file_contents)
	}
}

pub interface Iterator {
mut:
	next() ?string
}

pub struct LineIterator {
	data_ref []string
mut:
	idx int
}

pub fn (mut iter LineIterator) next() ?string {
	if iter.idx >= iter.data_ref.len {
		return none
	}
	defer { iter.idx += 1 }
	return iter.data_ref[iter.idx]
}

pub fn (buffer Buffer) iterate(cb fn (id int, line string)) {
	mut iter := buffer.iterator()
	mut idx  := 0
	for {
		line := iter.next() or { break }
		cb(idx, line)
		idx += 1
	}
}

pub fn (buffer Buffer) iterator() Iterator {
	if buffer.use_gap_buffer {
		return new_gap_buffer_iterator(buffer.c_buffer)
	}
	return LineIterator{
		data_ref: buffer.lines
	}
}

