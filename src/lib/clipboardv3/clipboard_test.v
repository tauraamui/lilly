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

