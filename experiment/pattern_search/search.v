@[translated]
module main

fn compute_lpsa_rray(pattern string, pattern_length int, lps []int) {
	length := 0
	// length of the previous longest prefix suffix
	lps[0] = 0
	// lps[0] is always 0
	i := 1
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

fn kmps_earch(text string, pattern string) {
	text_length := text.len
	pattern_length := pattern.len
	lps := []int{ len: pattern_length }
	// Preallocated memory for LPS array
	compute_lpsa_rray(pattern, pattern_length, lps)
	i := 0
	// index for text
	j := 0
	// index for pattern
	for i < text_length {
		if pattern[j] == text[i] {
			i++
			j++
		}
		if j == pattern_length {
			println("Pattern found at index ${i - j}")
			j = lps[j - 1]
		} else if i < text_length && pattern[j] != text[i] {
			if j != 0 {
				j = lps[j - 1]
			} else {
				i++
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
