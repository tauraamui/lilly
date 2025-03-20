module clipboard

@[heap]
struct MockClipboard {
mut:
	copied_content        string
	was_copy_unsuccessful bool
}

fn (mut mockclipboard MockClipboard) copy(text string) bool {
	mockclipboard.copied_content = text
	return !mockclipboard.was_copy_unsuccessful
}

fn (mut mockclipboard MockClipboard) paste() string {
	return mockclipboard.copied_content
}
