module buffer

struct LineBuffer {
mut:
	lines []string
}

pub fn (mut l_buffer LineBuffer) insert_text(pos Position, s string) ?Position {
	if l_buffer.lines.len - 1 < pos.line {
		l_buffer.lines << []string{ len: pos.line - l_buffer.lines.len + 1 }
		l_buffer.lines[pos.line] = s
		return Position.new(pos.line, s.runes().len)
	}

	line_content := l_buffer.lines[pos.line]
	mut clamped_offset := if pos.offset > line_content.len { line_content.len } else { pos.offset }
	if clamped_offset > line_content.runes().len { return Position.new(pos.line, clamped_offset) }

	pre_line_content  := line_content.runes()[..clamped_offset].string()
	post_line_content := line_content.runes()[clamped_offset..line_content.runes().len].string()

	l_buffer.lines[pos.line] = "${pre_line_content}${s}${post_line_content}"

	clamped_pos := Position.new(pos.line, clamped_offset)

	return clamped_pos.add(Distance{ lines: 0, offset: s.runes().len })
}

pub fn (mut l_buffer LineBuffer) insert_tab(pos Position, tabs_not_spaces bool) ?Position {
	if tabs_not_spaces { return l_buffer.insert_text(pos, '\t') }
	return l_buffer.insert_text(pos, " ".repeat(4))
}

