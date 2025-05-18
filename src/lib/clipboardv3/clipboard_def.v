module clipboardv3

pub enum ContentType as u8 {
	@none
	inline
	block
}

pub interface Clipboard {
	get_content() ?ClipboardContent
	set_content(content ClipboardContent)
}

