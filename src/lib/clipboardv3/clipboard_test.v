module clipboardv3

fn test_clipboard_native_implementation() ! {
	ct := ContentType.inline
	clipboard := new() or { return error("unable to acquire clipboard") }
	clipboard.set_content(ClipboardContent{ data: "This is copied text!", t_type: .inline })
	assert clipboard.get_content() or {
		return error("failed to get contents")
	} == ClipboardContent{ data: "This is copied text!", t_type: .inline }
}

