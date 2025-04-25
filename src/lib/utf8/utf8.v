module utf8

pub fn str_clamp_to_visible_length(s string, max_width int) string {
	if max_width <= 0 {
		return ""
	}

	if utf8_str_visible_length(s) <= max_width {
		return s
	}

	mut result := []rune{}
	mut current_width := 0
	mut i := 0

	s_bytes := s.bytes()
	for i < s_bytes.len {
		// determine utf-8 sequence length for current char
		c_char := s_bytes[i]
		ul := ((0xe5000000 >> ((c_char >> 3) & 0x1e)) & 3) + 1

		if i + ul > s_bytes.len {
			break
		}

		// copy all bytes for current char into temporary slice to check visual len
		temp := s_bytes[i..(i + ul)].byterune() or { break }
		visual_width := utf8_str_visible_length([temp].string())

		if current_width + visual_width > max_width {
			break
		}

		result << temp
		current_width += visual_width

		i += ul
	}

	return result.string()
}
