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

pub fn (mut buffer Buffer) insert_text(pos Pos, s string) ?Pos {
	mut cursor := pos
	if buffer.use_gap_buffer {
		for c in s.runes() {
			buffer.write(c)
			cursor.x += 1
			if c == lf {
				cursor.y += 1
				cursor.x = 0
			}
		}
		return cursor
	}
	return none
}

pub fn (mut buffer Buffer) write(r rune) {
	buffer.c_buffer.insert(r)
}

pub fn (mut buffer Buffer) write_at(r rune, pos Pos) {
	buffer.c_buffer.insert_at(r, pos)
}

pub fn (mut buffer Buffer) enter(pos Pos) ?Pos {
	if buffer.use_gap_buffer {
		buffer.move_cursor_to(pos)
		return buffer.insert_text(pos, lf.str())
	}
	return none
}

pub fn (mut buffer Buffer) backspace(pos Pos) ?Pos {
	mut cursor := pos
	if cursor.x == 0 && cursor.y == 0 { return none }
	if buffer.use_gap_buffer {
		buffer.move_cursor_to(pos)
		if buffer.c_buffer.backspace() {
			cursor.y -= 1
			cursor.x = buffer.find_end_of_line(cursor) or { 0 }
			return cursor
		}
		cursor.x -= 1
		if cursor.x < 0 { cursor.x = 0 }
		return cursor
	}

	mut line := buffer.lines[cursor.y]
	if cursor.x == 0 {
		previous_line := buffer.lines[cursor.y - 1]
		buffer.lines[cursor.y - 1] = "${previous_line}${buffer.lines[cursor.y]}"
		buffer.lines.delete(cursor.y)
		cursor.y -= 1
		cursor = buffer.clamp_cursor_within_document_bounds(cursor)
		cursor.x = previous_line.len

		if cursor.y < 0 {
			cursor.y = 0
		}
		return cursor
	}

	if cursor.x == line.len {
		buffer.lines[cursor.y] = line.runes()[..line.len - 1].string()
		cursor.x = buffer.lines[cursor.y].len
		return cursor
	}

	before := line.runes()[..cursor.x - 1].string()
	after := line.runes()[cursor.x..].string()
	buffer.lines[cursor.y] = "${before}${after}"
	cursor.x -= 1
	if cursor.x < 0 {
		cursor.x = 0
	}

	return cursor
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

	mut compound_y := 0
	for i := cursor.y; i >= 0; i-- {
		if i == cursor.y { continue }
		compound_y += 1
		if buffer.lines[i].len == 0 {
			break
		}
	}

	if compound_y > 0 {
		cursor.x = 0
		cursor.y -= compound_y
		return cursor
	}

	return none
}

pub fn (buffer Buffer) down_to_next_blank_line(pos Pos) ?Pos {
	if buffer.use_gap_buffer {
		return buffer.c_buffer.down_to_next_blank_line(pos)
	}

	mut cursor := pos
	cursor = buffer.clamp_cursor_within_document_bounds(pos)

	if buffer.lines.len == 0 { return none }
	if cursor.y == buffer.lines.len { return none }

	mut compound_y := 0
	for i := cursor.y; i < buffer.lines.len; i++ {
		if i == cursor.y { continue }
		compound_y += 1
		if buffer.lines[i].len == 0 {
			break
		}
	}

	if compound_y > 0 {
		cursor.x = 0
		cursor.y += compound_y
		return cursor
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

