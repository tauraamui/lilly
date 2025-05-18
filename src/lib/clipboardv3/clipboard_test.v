module clipboardv3

fn test_clipboard_native_implementation() ! {
	$if darwin {
		clipboard := new() or { return error("unable to acquire clipboard") }
		clipboard.set_content(ClipboardContent{ data: "This is copied text!", t_type: .inline })
		assert clipboard.get_content() or {
			return error("failed to get contents")
		} == ClipboardContent{ data: "This is copied text!", t_type: .inline }
	}
}

fn test_clipboard_native_implementation_sets_type_to_block() ! {
	$if darwin {
		clipboard := new() or { return error("unable to acquire clipboard") }
		clipboard.set_content(ClipboardContent{ data: "This is copied text!", t_type: .block })
		assert clipboard.get_content() or {
			return error("failed to get contents")
		} == ClipboardContent{ data: "This is copied text!", t_type: .block }
	}
}

fn test_clipboard_native_implementation_returns_no_content_type_from_plaintext_data() ! {
	$if darwin {
		C.clipboard_set_plaintext("A plain text sentence with no meta data!".str)
		clipboard := new() or { return error("unable to acquire clipboard") }
		assert clipboard.get_content() or {
			return error("failed to get contents")
		} == ClipboardContent{ data: "A plain text sentence with no meta data!", t_type: .none }
	}
}

