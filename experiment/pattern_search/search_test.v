module main

fn test_compute_lps_buffer_from_pattern() {
	pattern := "ABACDABAB"
	mut lsp := []int{ len: pattern.len }
	compute_lps_buffer(pattern, mut &lsp)
	assert lsp == [0, 0, 1, 0, 0, 1, 2, 3, 2]
}

