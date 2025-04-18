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

	s_runes := s.runes()
	for i < s_runes.len {
		// determine utf-8 sequence length for current char
		c_char := s_runes[i]
		ul := ((0xe5000000 >> ((c_char >> 3) & 0x1e)) & 3) + 1
		println("UTF-8 SEQ LEN: ${ul}")
		i += 1
	}

	/*
	for i < s.len {
		c := s.runes()[i]
		// Determine UTF-8 sequence length for current character
		ul := ((0xe5000000 >> ((c >> 3) & 0x1e)) & 3) + 1

		// Check for incomplete UTF-8 sequence
		if i + ul > s.len {
			break
		}

		// Calculate how this character would affect the visual width
		prev_width := current_width

		// Copy the current character to temporary slice to check its visual length
		mut char_bytes := []rune{len: ul}
		for j := 0; j < ul; j++ {
			char_bytes[j] = s.runes()[i + j]
			// char_bytes[j] = unsafe { s.str[i + j] }
		}

		temp_str := char_bytes.str()
		char_width := utf8_str_visible_length(temp_str)

		// If adding this character would exceed max_width, stop
		if current_width + char_width > max_width {
			break
		}

		// Add current character bytes to result
		for j := 0; j < ul; j++ {
			result << unsafe { s.str[i + j] }
		}

		current_width += char_width
		i += ul
	}
	*/

	return result.str()
}
