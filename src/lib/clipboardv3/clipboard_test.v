module clipboardv3

fn test_clipboard_native_implementation() ! {
	mut clipboard := new()
	clipboard.set_content(ClipboardContent{ data: "This is copied text!", type: .inline })
	assert clipboard.get_content() or {
		return error("failed to get contents")
	} == ClipboardContent{ data: "This is copied text!", type: .inline }
}

fn test_clipboard_native_implementation_sets_type_to_block() ! {
	mut clipboard := new()
	clipboard.set_content(ClipboardContent{ data: "This is copied text!", type: .block })
	assert clipboard.get_content() or {
		return error("failed to get contents")
	} == ClipboardContent{ data: "This is copied text!", type: .block }
}

fn test_clipboard_native_implementation_returns_no_content_type_from_plaintext_data() {
	$if darwin {
		C.clipboard_set_plaintext("A plain text sentence with no meta data!".str)
		clipboard := new()
		assert clipboard.get_content()! == ClipboardContent{ data: "A plain text sentence with no meta data!", type: .block }
	} $else { assert true }
}

