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

module clipboardv3

pub enum ContentType as u8 {
	@none
	inline
	block
}

pub struct ClipboardContent {
pub mut:
	data string
	type ContentType
}

pub interface Clipboard {
mut:
	get_content() ?ClipboardContent
	set_content(content ClipboardContent)
}

pub fn new() Clipboard {
	$if test {
		return new_fallback_clipboard()
	}

	$if darwin {
		return new_darwin_clipboard()
	}

	$if linux {
		return new_linux_clipboard()
	}
	return new_fallback_clipboard()
}
