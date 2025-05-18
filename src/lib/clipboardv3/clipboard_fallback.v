module clipboardv3

struct FallbackClipboard{
mut:
	content ?ClipboardContent
}

fn new_fallback_clipboard() Clipboard {
	return FallbackClipboard{}
}

fn (clipboard FallbackClipboard) get_content() ?ClipboardContent {
	return clipboard.content
}

fn (mut clipboard FallbackClipboard) set_content(content ClipboardContent) {
	clipboard.content = content
}

