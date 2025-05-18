module clipboardv3

pub enum ContentType as u8 {
	@none
	inline
	block
}

pub struct ClipboardContent {
pub mut:
	data   string
	type ContentType
}

pub interface Clipboard {
	get_content() ?ClipboardContent
mut:
	set_content(content ClipboardContent)
}

pub fn new() Clipboard {
	$if darwin {
		return new_darwin_clipboard()
	}
	return new_fallback_clipboard()
}

