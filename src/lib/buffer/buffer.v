module buffer

pub struct Buffer {
pub:
	file_path string
pub mut:
	auto_close_chars []string
	lines            []string
	use_gap_buffer   bool
	dirty            bool
mut:
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
		buffer.load_contents_into_gap(buffer.lines.join("\n"))
	}
}

pub fn (mut buffer Buffer) load_contents_into_gap(contents string) {
	if !buffer.use_gap_buffer { return }
	buffer.c_buffer = GapBuffer.new(contents)
}

pub fn (mut buffer Buffer) move_cursor_to(pos Pos) {
	buffer.c_buffer.move_cursor_to(pos)
}

pub fn (mut buffer Buffer) write(r rune) {
	buffer.c_buffer.insert(r)
}

pub fn (mut buffer Buffer) write_at(r rune, pos Pos) {
	buffer.c_buffer.insert_at(r, pos)
}

pub fn (mut buffer Buffer) backspace() bool {
	return buffer.c_buffer.backspace()
}

pub fn (mut buffer Buffer) delete() {
	buffer.c_buffer.delete(true)
}

pub fn (mut buffer Buffer) str() string {
	return buffer.c_buffer.str()
}

pub fn (buffer Buffer) find_end_of_line(pos Pos) ?int {
	return buffer.c_buffer.find_end_of_line(pos)
}

pub fn (buffer Buffer) find_next_word_start(pos Pos) ?Pos {
	return buffer.c_buffer.find_next_word_start(pos)
}

pub fn (buffer Buffer) find_next_word_end(pos Pos) ?Pos {
	return buffer.c_buffer.find_next_word_end(pos)
}

pub fn (buffer Buffer) find_prev_word_start(pos Pos) ?Pos {
	return buffer.c_buffer.find_prev_word_start(pos)
}

pub fn (buffer Buffer) left(pos Pos, insert_mode bool) ?Pos {
	if buffer.use_gap_buffer {
		return buffer.c_buffer.left(pos)
	}
	mut cursor := pos
	cursor.x -= 1
	cursor = buffer.clamp_cursor_x_pos(cursor, insert_mode)
	return cursor
}

pub fn (buffer Buffer) right(pos Pos, insert_mode bool) ?Pos {
	if buffer.use_gap_buffer {
		return buffer.c_buffer.right(pos)
	}
	mut cursor := pos
	cursor.x += 1
	cursor = buffer.clamp_cursor_x_pos(cursor, insert_mode)
	return cursor
}

pub fn (buffer Buffer) down(pos Pos, insert_mode bool) ?Pos {
	if buffer.use_gap_buffer {
		return buffer.c_buffer.down(pos)
	}
	return none
}

pub fn (buffer Buffer) up(pos Pos, insert_mode bool) ?Pos {
	if buffer.use_gap_buffer {
		return buffer.c_buffer.up(pos)
	}
	return none
}

pub fn (buffer Buffer) up_to_next_blank_line(pos Pos) ?Pos {
	if buffer.use_gap_buffer {
		return buffer.c_buffer.up_to_next_blank_line(pos)
	}
	mut cursor := pos
	cursor = buffer.clamp_cursor_within_document_bounds(pos)
	if cursor.y == 0 { return none }

	if buffer.lines.len == 0 { return none }

	for i := cursor.y; i >= 0; i-- {
		if i == cursor.y { continue }
		if buffer.lines[i].len == 0 {
			// cursor.y -= i
		}
	}

	return none
}

fn (buffer Buffer) clamp_cursor_within_document_bounds(pos Pos) Pos {
	mut cursor := pos
	if pos.y < 0 {
		cursor.y = 0
	}
	if cursor.y > buffer.lines.len - 1 {
		cursor.y = buffer.lines.len - 1
	}
	return cursor
}

fn (buffer Buffer) clamp_cursor_x_pos(pos Pos, insert_mode bool) Pos {
	mut clamped := buffer.clamp_cursor_within_document_bounds(pos)
	if clamped.x < 0 { clamped.x = 0 }

	current_line_len := buffer.lines[pos.y].runes().len

	if insert_mode {
		if clamped.x > current_line_len {
			clamped.x = current_line_len
		}
	}
	return clamped
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

