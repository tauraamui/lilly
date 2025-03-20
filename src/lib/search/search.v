module search

fn compute_lps(pattern []rune, mut lps []int) {
	mut i := 1
	mut j := 0

	for i < pattern.len {
		if pattern[i] == pattern[j] {
			j += 1
			lps[i] = j
			i += 1
			continue
		}
		if j > 0 {
			j = lps[j - 1]
			continue
		}
		lps[i] = 0
		i += 1
	}
}

pub fn kmp(text []rune, pattern []rune) int {
	mut lps := []int{ len: pattern.len }
	compute_lps(pattern, mut lps)

	mut i := 0
	mut j := 0

	for i < text.len {
		if text[i] == pattern[j] {
			if j == pattern.len - 1 {
				return i - j
			}
			i += 1
			j += 1
			continue
		}
		// use lps to skip comps
		if j > 0 {
			j = lps[j - 1]
		} else {
			i += 1
		}
	}

	return -1
}

