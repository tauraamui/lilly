module main

fn compute_lps_buffer(pattern string, mut lps []int) {
	mut length := 0

	// lps index 0 is always 0
	lps[0] = 0

	mut i := 1
	for i < pattern.len {
		if pattern[i] == pattern[length] {
			length += 1
			lps[i] = length
			i += 1
			continue
		}
		if length != 0 {
			length = lps[length - 1]
			continue
		}
		lps[i] = 0
		i += 1
	}
	println(lps)
}

fn kmps_earch(text string, pattern string) {
	text_length := text.len
	pattern_length := pattern.len
	mut lps := []int{ len: pattern_length }
	// Preallocated memory for LPS array
	compute_lps_buffer(pattern, mut lps)
	mut i := 0
	// index for text
	mut j := 0
	// index for pattern
	for i < text_length {
		if pattern[j] == text[i] {
			i += 1
			j += 1
		}
		if j == pattern_length {
			println("Pattern found at index ${i - j}")
			j = lps[j - 1]
		} else if i < text_length && pattern[j] != text[i] {
			if j != 0 {
				j = lps[j - 1]
			} else {
				i += 1
			}
		}
	}
}

fn main() {
	text := 'ABABDABACDABABCABAB'
	pattern := 'ABABCABAB'
	kmps_earch(text, pattern)
	return
}
