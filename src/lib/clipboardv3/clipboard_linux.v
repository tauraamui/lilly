module clipboardv3

import os

struct LinuxClipboard{}

fn new_linux_clipboard() Clipboard {
	return LinuxClipboard{}
}

fn (c LinuxClipboard) get_content() ?ClipboardContent {
	mut cmd := os.new_process("xclip")
	defer { cmd.close() }
	cmd.set_args(["-selection", "clipboard", "-out"])
	cmd.set_redirect_stdio()
	cmd.run()

	mut data := ""
	mut read_from_stdout := false
	if cmd.is_pending(.stdout) {
		read_from_stdout = true
		data = cmd.stdout_read()
	}
	cmd.wait()
	if read_from_stdout == false {
		return none
	}
	return ClipboardContent{
		data: data,
		type: .block
	}
}

fn (c LinuxClipboard) set_content(content ClipboardContent) {
}

