module clipboard

pub interface Clipboard {
mut:
	copy(text string) bool
	paste() []string
}

pub fn new() Clipboard {
	return new_clipboard()
}

