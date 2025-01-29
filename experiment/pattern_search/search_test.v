module main

fn test_compute_lps_buffer_from_pattern() {
	pattern := "ABACDABAB"
	mut lsp := []int{ len: pattern.len }
	compute_lps(pattern, mut lsp)
	assert lsp == [0, 0, 1, 0, 0, 1, 2, 3, 2]
}

fn test_kmp_search() {
	mut text := "// TODO(tauraamui) [29/01/25]: some comment contents"
	mut pattern := "TODO"
	assert kmp(text, pattern) == 3

	text = "ABABDABACDABABCABAB"
	pattern = "ABACDABAB"
	assert kmp(text, pattern) == 5
}

