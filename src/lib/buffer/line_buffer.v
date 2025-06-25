module buffer

struct LineBuffer {
mut:
	lines []string
}

pub fn (mut l_buffer LineBuffer) insert_text(pos Position, s string) ?Position {
	// handle if set of lines up to position don't exist
	if l_buffer.expansion_required(pos) {
		return grow_and_set(mut l_buffer.lines, pos.line, s)
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

pub fn (mut l_buffer LineBuffer) newline(pos Position) ?Position {
	// handle if set of lines up to position don't exist
	if l_buffer.expansion_required(pos) {
		return grow_and_set(mut l_buffer.lines, pos.line, [lf].string())
	}

	line_at_pos := l_buffer.lines[pos.line]
	clamped_offset := if pos.offset > line_at_pos.runes().len { line_at_pos.runes().len } else { pos.offset }
	content_after_cursor := line_at_pos[clamped_offset..]
	return none
}

fn (l_buffer LineBuffer) expansion_required(pos Position) bool {
	return l_buffer.lines.len - 1 < pos.line
}

fn grow_and_set(mut lines []string, pos_line int, data_to_set string) Position {
	s := data_to_set
	lines << []string{ len: pos_line - lines.len + 1 }
	lines[pos_line] = s
	return Position.new(pos_line, s.runes().len)
}

