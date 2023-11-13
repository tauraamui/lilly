module clipboard

fn new_clipboard() Clipboard {
	$if test {
		return &MockClipboard{}
	}
	return &XClipClipboard{}
}
