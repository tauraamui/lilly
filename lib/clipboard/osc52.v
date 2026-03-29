// Copyright 2026 The Lilly Edtior contributors
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

module clipboard

import encoding.base64
import os

struct Osc52Clipboard {
mut:
	fallback FallbackClipboard
}

fn new_osc52_clipboard() Clipboard {
	return Osc52Clipboard{}
}

fn (mut cb Osc52Clipboard) get_content() ?ClipboardContent {
	// OSC 52 read (query) is blocked by most terminals for security
	// reasons, so we rely on the internal fallback for paste.
	return cb.fallback.get_content()
}

fn (mut cb Osc52Clipboard) set_content(content ClipboardContent) {
	cb.fallback.set_content(content)

	encoded := base64.encode_str(content.data)
	// OSC 52: \x1b]52;c;<base64>\x07
	// 'c' targets the system clipboard selection.
	sequence := '\x1b]52;c;${encoded}\x07'
	os.fd_write(1, sequence)
}
