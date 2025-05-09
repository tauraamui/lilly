// Copyright 2025 The Lilly Edtior contributors
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

module utf8

fn test_str_clamp_to_visible_length_match_max_to_str_len() {
	example_str := "A1B2C3D4E5"
	assert str_clamp_to_visible_length(example_str, example_str.len) == "A1B2C3D4E5"
}

fn test_str_clamp_to_visible_length_max_less_str_len() {
	example_str := "A1B2C3D4E5"
	assert str_clamp_to_visible_length(example_str, 3) == "A1B"
}

fn test_str_clamp_to_visible_length_shark_emoji_less_than_visual_size() {
	// shark emoji visually takes up 2 chars
	example_str := emoji_shark_char
	assert str_clamp_to_visible_length(example_str, 1) == ""
}

fn test_str_clamp_to_visible_length_shark_emoji_to_same_as_visual_size() {
	// shark emoji visually takes up 2 chars
	example_str := emoji_shark_char
	assert str_clamp_to_visible_length(example_str, 2) == emoji_shark_char
}

fn test_str_clamp_to_visible_length_shark_emoji_to_more_than_visual_size() {
	// shark emoji visually takes up 2 chars
	example_str := emoji_shark_char
	assert str_clamp_to_visible_length(example_str, 20) == emoji_shark_char
}

