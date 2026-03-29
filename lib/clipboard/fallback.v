module clipboard

struct FallbackClipboard {
mut:
	content ?ClipboardContent
}

fn new_fallback_clipboard() Clipboard {
	return FallbackClipboard{}
}

fn (mut cb FallbackClipboard) get_content() ?ClipboardContent {
	return cb.content
}

fn (mut cb FallbackClipboard) set_content(content ClipboardContent) {
	cb.content = content
}
