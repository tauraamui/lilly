module clipboardv2

pub enum ContentType as u8 {
	@none
	inline
	block
}

pub struct ClipboardContent {
pub:
	type        ContentType
	data         string
}

pub struct Clipboard {
mut:
	content ClipboardContent
}

pub fn new() &Clipboard {
	return &Clipboard{
		content: ClipboardContent{ type: .none }
	}
}

pub fn (mut clipboard Clipboard) get_content() ClipboardContent {
	return clipboard.content
}

pub fn (mut clipboard Clipboard) set_content(content ClipboardContent) {
	clipboard.content = content
	// update system clipboard here
}
