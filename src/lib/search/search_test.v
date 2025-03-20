// Copyright 2025 The Lilly Editor contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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

