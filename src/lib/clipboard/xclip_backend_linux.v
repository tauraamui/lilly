module clipboard

[heap]
struct XClipClipboard {
mut:
	content string
}

fn new_clipboard() &XClipClipboard {
	return &XClipClipboard{}
}

fn (mut xclipboard XClipClipboard) copy(text string) bool { xclipboard.content = text; return true }

fn (xclipboard XClipClipboard) paste() string { return xclipboard.content }
