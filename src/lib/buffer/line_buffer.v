module buffer

import arrays

struct LineBuffer {
mut:
	lines []string
}

fn LineBuffer.new(d []string) LineBuffer {
	return LineBuffer{ lines: d }
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
		post_expand_pos := grow_and_set(mut l_buffer.lines, pos.line, "")
		l_buffer.lines << [""]
		return post_expand_pos.add(Distance{ lines: 1, offset: 0 })
	}

	line_at_pos := l_buffer.lines[pos.line]
	clamped_offset := if pos.offset > line_at_pos.runes().len { line_at_pos.runes().len } else { pos.offset }
	content_after_cursor := line_at_pos[clamped_offset..]
	content_before_cursor := line_at_pos[..clamped_offset]

	whitespace_prefix := resolve_whitespace_prefix_from_line(content_before_cursor)
	l_buffer.lines[pos.line] = content_before_cursor
	l_buffer.lines.insert(pos.line + 1, "${whitespace_prefix}${content_after_cursor}")
	return Position.new(pos.line, 0).add(Distance{ lines: 1, offset: whitespace_prefix.runes().len })
}

fn resolve_whitespace_prefix_from_line(line string) string {
	// when mapping over rune data, we acquire the first index for which a
	// char is not empty/whitespace. first visible char we encounter, we return the index! :)
	pre_prefix_index := arrays.index_of_first(line.runes(), fn (idx int, cchar rune) bool { return !is_whitespace(cchar) })
	return match pre_prefix_index {
		-1   { "" }
		0    { "" }
		else { line.runes()[..pre_prefix_index].string() }
	}
}

pub fn (mut l_buffer LineBuffer) x(pos Position) Position {
	if l_buffer.is_oob(pos) { return pos }

	line_at_pos := l_buffer.lines[pos.line]
	if line_at_pos.len == 0 { return pos }

	clamped_offset := if pos.offset >= line_at_pos.runes().len { line_at_pos.runes().len - 1 } else { pos.offset }
	mut line_content := l_buffer.lines[pos.line].runes()
	line_content.delete(clamped_offset)
	l_buffer.lines[pos.line] = line_content.string()

	return Position.new(pos.line, clamped_offset)
}

pub fn (mut l_buffer LineBuffer) backspace(pos Position) ?Position {
	if pos.line == 0 && pos.offset == 0 { return pos }

	clamped_pos := if l_buffer.is_oob(pos) { Position.new(l_buffer.lines.len - 1, l_buffer.lines[l_buffer.lines.len - 1].runes().len - 1) } else { pos }

	line_at_pos := l_buffer.lines[clamped_pos.line]
	if clamped_pos.offset > 0 {
		mut line_content := l_buffer.lines[clamped_pos.line].runes()
		line_content.delete(clamped_pos.offset)
		l_buffer.lines[clamped_pos.line] = line_content.string()
		return clamped_pos.add(Distance{ 0, -1 })
	}

	line_content := l_buffer.lines[clamped_pos.line]
	if clamped_pos.line - 1 >= 0 {
		length_pre_append := l_buffer.lines[clamped_pos.line - 1].runes().len
		l_buffer.lines[clamped_pos.line - 1] = "${l_buffer.lines[clamped_pos.line - 1]}${line_content}"
		l_buffer.lines.delete(clamped_pos.line)
		return clamped_pos.add(Distance{ -1, length_pre_append - 1 })
	}

	return none
}

pub fn (l_buffer LineBuffer) delete(ignore_newlines bool) bool {
	return false
}

pub fn (mut l_buffer LineBuffer) o(pos Position) ?Position {
	if l_buffer.expansion_required(pos) {
		post_expand_pos := grow_and_set(mut l_buffer.lines, pos.line, "")
		l_buffer.lines << [""]
		return post_expand_pos.add(Distance{ lines: 1, offset: 0 })
	}
	l_buffer.lines.insert(pos.line + 1, "")
	return Position.new(pos.line, 0).add(Distance{ lines: 1 })
}

pub fn (l_buffer LineBuffer) num_of_lines() int { return l_buffer.lines.len }

pub fn (l_buffer LineBuffer) str() string {
	return l_buffer.lines.join("\n")
}

fn (l_buffer LineBuffer) is_oob(pos Position) bool {
	return l_buffer.lines.len - 1 < pos.line
}

fn (l_buffer LineBuffer) expansion_required(pos Position) bool {
	return l_buffer.is_oob(pos)
}

fn grow_and_set(mut lines []string, pos_line int, data_to_set string) Position {
	s := data_to_set
	lines << []string{ len: pos_line - lines.len + 1 }
	lines[pos_line] = s
	return Position.new(pos_line, s.runes().len)
}

