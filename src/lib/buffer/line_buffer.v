module buffer

struct LineBuffer {
mut:
	lines []string
}

pub fn (mut l_buffer LineBuffer) insert_text(pos Position, s string) ?Position {
	line_id := pos.line
	mut line_content := l_buffer.lines[line_id]
	if line_content.len == 0 {
		l_buffer.lines[line_id] = s
		return Position.new(line_id, s.runes().len)
	}
	return none
}

