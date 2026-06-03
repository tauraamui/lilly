module buffers

fn test_text_buffer_init() {
	TextBuffer.new()
	assert true
}

fn test_text_buffer_get_line_bytes() {
	mut tb := TextBuffer.new()
	tb.insert(u8(`H`))
	tb.insert(u8(`e`))
	tb.insert(u8(`l`))
	tb.insert(u8(`l`))
	tb.insert(u8(`o`))

	assert tb.get_line_bytes(0) == [u8(`H`), `e`, `l`, `l`, `o`]
}


