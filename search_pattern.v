module main

fn compute_lps_array(pattern string, pattern_length int, mut lps []int) {
	mut length := 0
	lps[0] = 0
	mut i := 1
	for i < pattern_length {
		if pattern[i] == pattern[length] {
			length++
			lps[i] = length
			i++
		} else {
			if length != 0 {
				length = lps[length - 1]
			} else {
				lps[i] = 0
				i++
			}
		}
	}
}

fn matches_pattern(text string, pattern string, start_index int) bool {
	mut i := start_index
	mut j := 0
	text_length := text.len
	pattern_length := pattern.len

	for j < pattern_length && i < text_length {
		if pattern[j].str() == "{" {
			// Skip variable part
			j++
			for j < pattern_length && pattern[j].str() != "}" {
				j++
			}
			if j < pattern_length {
				j++ // Skip '}'
			}
			// Move i to the end of the variable part
			for i < text_length && text[i].str() != ' ' && text[i].str() != ']' {
				i++
			}
		} else if pattern[j] == text[i] {
			i++
			j++
		} else {
			return false
		}
	}
	return j == pattern_length
}

fn find_pattern(text string, pattern string) {
	text_length := text.len
	pattern_length := pattern.len
	mut lps := []int{ len: pattern_length }
	compute_lps_array(pattern, pattern_length, mut lps)

	mut i := 0 // index for text
	for i < text_length {
		if matches_pattern(text, pattern, i) {
			println("Pattern found at index $i")
		}
		i++
	}
}

fn main() {
	text := 'This is a sample text with TODO(tauraamui) [20/01/25] and ' +
	        'another TODO(johndoe) [21/02/26] in it.'
	pattern := 'TODO({username}) [{date}]'
	find_pattern(text, pattern)
}
