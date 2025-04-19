module utf8

pub fn str_clamp_to_visible_length(s string, max_width int) string {
	if max_width <= 0 {
		return ""
	}

	if utf8_str_visible_length(s) <= max_width {
		return s
	}

	mut result := []u8{}
	mut current_width := 0
	mut i := 0

	s_bytes := s.bytes()
	for i < s_bytes.len {
		// determine utf-8 sequence length for current char
		c_char := s_bytes[i]
		ul := ((0xe5000000 >> ((c_char >> 3) & 0x1e)) & 3) + 1
		println("UTF-8 SEQ LEN: ${ul}")

		if i + ul > s_bytes.len {
			break
		}

		prev_width := current_width
		// copy all bytes for current char into temporary slice to check visual len
		temp := s_bytes[i..(i + ul)].byterune() or { break }
		println([temp].string())
		println(utf8_str_visible_length([temp].string()))

		i += ul
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
