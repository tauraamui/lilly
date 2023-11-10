module clipboard

fn test_clipboard_copy() {
	mut clip := new()
	assert clip.copy("some text")
	assert clip.paste() == ["some text"]
}

