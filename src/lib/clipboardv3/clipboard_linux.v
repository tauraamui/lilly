module clipboardv3

import lib.clipboardv3.x11

struct LinuxClipboard{
mut:
	x11_clipboard &x11.Clipboard
}

fn new_linux_clipboard() Clipboard {
	return LinuxClipboard{
		x11_clipboard: x11.new_clipboard()
	}
}

fn (mut c LinuxClipboard) get_content() ?ClipboardContent {
	return ClipboardContent{
		data: c.x11_clipboard.get_text()
		type: .block
	}
}

fn (mut c LinuxClipboard) set_content(content ClipboardContent) {
	c.x11_clipboard.set_text(content.data)
}

