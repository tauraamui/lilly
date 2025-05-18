module clipboardv3

pub enum ContentType as u8 {
	@none
	inline
	block
}

pub struct ClipboardContent {
mut:
	data   string
	t_type ContentType
}

pub interface Clipboard {
	get_content() ?ClipboardContent
	set_content(content ClipboardContent)
}

pub fn new() ?Clipboard {
	$if darwin {
		return new_darwin_clipboard()
	}
	return none
}

