module buffer

pub struct Buffer {
pub:
	file_path string
pub mut:
	lines            []string
	auto_close_chars []string
	cursor           Pos
mut:
	use_gap_buffer   bool
	c_buffer         GapBuffer
	// line_tracker LineTracker
}

pub struct Pos {
pub mut:
	x int
	y int
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

pub fn (mut buffer Buffer) move_cursor_to(x int, y int) {
	buffer.cursor.x = x
	buffer.cursor.y = y
	if buffer.use_gap_buffer {
		// TODO(tauraamui): move the gap to the correct position offset
	}
}

pub fn (mut buffer Buffer) insert_text(s string) {
	if buffer.use_gap_buffer {
		buffer.c_buffer.insert(s)
		return
	}

	line := buffer.lines[buffer.cursor.y]

	defer { buffer.cursor.x += s.runes().len }
	if line.len == 0 {
		buffer.lines[buffer.cursor.y] = "${s}"
		buffer.cursor.x = s.runes().len
		return
	} else {
		if buffer.cursor.x > line.len {
			buffer.cursor.x = line.len
		}
		uline := line.runes()
		if buffer.cursor.x > uline.len {
			return
		}

		left := uline[..buffer.cursor.x].string()
		right := uline[buffer.cursor.x..uline.len].string()

		buffer.lines[buffer.cursor.y] = "${left}${s}${right}"
	}

	buffer.cursor.x += s.runes().len
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

