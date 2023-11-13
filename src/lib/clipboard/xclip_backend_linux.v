module clipboard

import os

[heap]
struct XClipClipboard {
mut:
	content string
}

fn new_clipboard() Clipboard {
	$if test {
		return &MockClipboard{}
	}
	return &XClipClipboard{}
}

fn (mut xclipboard XClipClipboard) copy(text string) bool {
	mut cmd := os.Command{
		path: "echo '${text}' | xclip -i -r"
	}
	defer { cmd.close() or { } }
	cmd.start() or { return false }
	return cmd.exit_code == 0
}

fn (xclipboard XClipClipboard) paste() []string {
	mut cmd := os.Command{
		path: "xclip -o"
	}
	defer { cmd.close() or { } }
	cmd.start() or { panic(err) }

	mut out := []string{}
	for {
		out << cmd.read_line()
		if cmd.eof { break }
	}

	if cmd.exit_code == 0 { return out }

	return []
}

