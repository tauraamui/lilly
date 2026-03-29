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

import os

enum LinuxBackend {
	wayland
	x11_xclip
	x11_xsel
	none
}

struct LinuxClipboard {
	backend LinuxBackend
mut:
	fallback FallbackClipboard
}

fn new_linux_clipboard() Clipboard {
	backend := detect_linux_backend()
	if backend == .none {
		return new_osc52_clipboard()
	}
	return LinuxClipboard{
		backend: backend
	}
}

fn (mut cb LinuxClipboard) get_content() ?ClipboardContent {
	if cb.backend == .none {
		return cb.fallback.get_content()
	}

	paste_cmd := match cb.backend {
		.wayland { 'wl-paste --no-newline' }
		.x11_xclip { 'xclip -selection clipboard -o' }
		.x11_xsel { 'xsel --clipboard --output' }
		.none { '' }
	}

	result := os.execute(paste_cmd)
	if result.exit_code != 0 || result.output.len == 0 {
		return cb.fallback.get_content()
	}

	// Check if the fallback has content with type metadata that matches
	// the system clipboard text — if so, preserve the type info.
	if fb_content := cb.fallback.get_content() {
		if fb_content.data == result.output {
			return fb_content
		}
	}

	return ClipboardContent{
		data: result.output
		@type: .block
	}
}

fn (mut cb LinuxClipboard) set_content(content ClipboardContent) {
	// Always store in the fallback to preserve type metadata.
	cb.fallback.set_content(content)

	if cb.backend == .none {
		return
	}

	// Redirect stdout/stderr to /dev/null — clipboard tools fork background
	// processes to serve paste requests, and those children inherit os.execute's
	// pipe FDs. Without the redirect, os.execute blocks forever waiting for EOF.
	copy_cmd := match cb.backend {
		.wayland { "wl-copy '${escaped(content.data)}' >/dev/null 2>&1" }
		.x11_xclip { "echo -n '${escaped(content.data)}' | xclip -selection clipboard >/dev/null 2>&1" }
		.x11_xsel { "echo -n '${escaped(content.data)}' | xsel --clipboard --input >/dev/null 2>&1" }
		.none { '' }
	}

	os.execute(copy_cmd)
}

fn escaped(s string) string {
	return s.replace("'", "'\\''")
}

fn detect_linux_backend() LinuxBackend {
	if os.getenv('WAYLAND_DISPLAY').len > 0 {
		if tool_exists('wl-copy') {
			return .wayland
		}
	}

	if os.getenv('DISPLAY').len > 0 {
		if tool_exists('xclip') {
			return .x11_xclip
		}
		if tool_exists('xsel') {
			return .x11_xsel
		}
	}

	return .none
}

fn tool_exists(name string) bool {
	result := os.execute('which ${name}')
	return result.exit_code == 0
}
