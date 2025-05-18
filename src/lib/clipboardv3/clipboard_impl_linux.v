module clipboardv3

struct LinuxClipboard {
}

pub fn new() Clipboard {
	return LinuxClipboard{}
}

fn (mut clipboard LinuxClipboard) get_content() ClipboardContent {}

fn (mut clipboard LinuxClipboard) set_content(content ClipboardContent) {}

