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

import os
import time

struct LinuxClipboard{
mut:
	last_type ContentType
}

fn new_linux_clipboard() Clipboard {
	return LinuxClipboard{
		last_type: .block
	}
}

fn (c LinuxClipboard) get_content() ?ClipboardContent {
	mut out := []string{}
	mut er := []string{}

	mut p := os.new_process('/usr/bin/xclip')
	p.set_args(["-selection", "clipboard", "-out"])
	p.set_redirect_stdio()
	p.run()

	for p.is_alive() {
		if data := p.pipe_read(.stderr) {
			er << data
		}
		if data := p.pipe_read(.stdout) {
			out << data
		}
		time.sleep(2 * time.millisecond)
	}

	out << p.stdout_slurp()
	er << p.stderr_slurp()
	p.close()
	p.wait()

	return ClipboardContent{
		data: out.join(''),
		type: c.last_type
	}
}

fn (mut c LinuxClipboard) set_content(content ClipboardContent) {
	mut p := os.new_process('/usr/bin/xclip')
	p.set_args(["-selection", "clipboard", "-in"])
	p.set_redirect_stdio()
	p.run()

	content_to_set := content.data
	p.stdin_write(content_to_set)
	os.fd_close(p.stdio_fd[0])

	p.close()
	p.wait()

	start := time.now()
	for {
		if (time.now() - start).milliseconds() >= 100 { break }
		current_clip_content := c.get_content() or { continue }
		if content_to_set == current_clip_content.data {
			break
		}
	}
	c.last_type = content.type
}

