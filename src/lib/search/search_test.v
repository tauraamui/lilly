module search

fn test_compute_lps_buffer_from_pattern() {
	pattern := "ABACDABAB".runes()
	mut lsp := []int{ len: pattern.len }
	compute_lps(pattern, mut lsp)
	assert lsp == [0, 0, 1, 0, 0, 1, 2, 3, 2]
}

fn test_kmp_search() {
	mut text := "// -x TODO(tauraamui) [29/01/25]: some comment contents".runes()
	mut pattern := "TODO".runes()
	assert kmp(text, pattern) == 6

	text = "ABABDABACDABABCABAB".runes()
	pattern = "ABACDABAB".runes()
	assert kmp(text, pattern) == 5
}

fn test_kmp_rudimentary_attempt_select_full_comment() {
	mut text := "// -x TODO(tauraamui) [29/01/25]: some comment contents".runes()
	mut pattern := "TODO".runes()
	start := kmp(text, pattern)
	end   := kmp(text, "]:".runes()) + "]:".len
	assert start == 6
	assert end == 33
	assert text[start..end].string() == "TODO(tauraamui) [29/01/25]:"
}

