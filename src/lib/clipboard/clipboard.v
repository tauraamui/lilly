module clipboard

pub interface Clipboard {
mut:
	copy(text string) bool
	paste() string
}

pub fn new() Clipboard {
	$if windows {
		return clipboard.new()
	} $else {
		return new_clipboard()
	}
}
