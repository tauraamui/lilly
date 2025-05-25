module clipboardv3

fn test_linux_clipboard_sets_contents() {
	mut lc := new_linux_clipboard()
	defer { lc.set_content(ClipboardContent{}) }

	lc.set_content(ClipboardContent{ data: "this is a test line of text" })
	assert lc.get_content()! == ClipboardContent{
		data: "this is a test line of text"
	}
}

fn test_linux_clipboard_via_interface_sets_contents() {
	mut c := new()
	defer { c.set_content(ClipboardContent{}) }

	c.set_content(ClipboardContent{ data: "this is a test line of text via interface wrap" })
	assert c.get_content()! == ClipboardContent{
		data: "this is a test line of text via interface wrap"
	}
}

