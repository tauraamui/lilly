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
	mut lps := []int{len: pattern.len}
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
