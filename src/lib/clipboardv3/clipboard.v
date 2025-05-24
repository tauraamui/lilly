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
mut:
	get_content() ?ClipboardContent
	set_content(content ClipboardContent)
}

pub fn new() Clipboard {
	$if darwin {
		return new_darwin_clipboard()
	}

	$if linux {
		return new_linux_clipboard()
	}
	return new_fallback_clipboard()
}

