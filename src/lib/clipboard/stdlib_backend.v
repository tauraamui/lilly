module clipboard

import clipboard as stdlib_clipboard

[heap]
struct StdLibClipboard {
mut:
	ref &stdlib_clipboard.Clipboard
}

fn (mut stdlibclipboard StdLibClipboard) copy(text string) bool {
	return stdlibclipboard.ref.copy(text)
}

fn (mut stdlibclipboard StdLibClipboard) paste() []string {
	return stdlibclipboard.ref.paste().split_into_lines()
}

