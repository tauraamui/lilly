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

	assert tb.get_line_bytes(0)? == [u8(`H`), `e`, `l`, `l`, `o`]
}

fn test_text_buffer_get_line_bytes_of_multiple_lines() {
	mut tb := TextBuffer.new()
	tb.insert(u8(`H`))
	tb.insert(u8(`e`))
	tb.insert(u8(`l`))
	tb.insert(u8(`l`))
	tb.insert(u8(`o`))
	tb.insert(u8(`\n`))
	tb.insert(u8(`W`))
	tb.insert(u8(`o`))
	tb.insert(u8(`r`))
	tb.insert(u8(`l`))
	tb.insert(u8(`d`))

	assert tb.get_line_bytes(0)? == [u8(`H`), `e`, `l`, `l`, `o`, `\n`]
	assert tb.get_line_bytes(1)? == [u8(`W`), `o`, `r`, `l`, `d`]
}

fn test_text_buffer_get_line_bytes_of_multiple_lines_post_backspace() {
	mut tb := TextBuffer.new()
	tb.insert(u8(`H`))
	tb.insert(u8(`e`))
	tb.insert(u8(`l`))
	tb.insert(u8(`l`))
	tb.insert(u8(`o`))
	tb.insert(u8(`\n`))
	tb.insert(u8(`W`))
	tb.insert(u8(`o`))

	assert tb.get_line_bytes(0)? == [u8(`H`), `e`, `l`, `l`, `o`, `\n`]
	assert tb.get_line_bytes(1)? == [u8(`W`), `o`]

	tb.backspace()
	assert tb.get_line_bytes(0)? == [u8(`H`), `e`, `l`, `l`, `o`, `\n`]
	assert tb.get_line_bytes(1)? == [u8(`W`)]

	tb.backspace()
	assert tb.get_line_bytes(0)? == [u8(`H`), `e`, `l`, `l`, `o`, `\n`]
	assert tb.get_line_bytes(1)? == []

	tb.backspace()
	assert tb.get_line_bytes(0)? == [u8(`H`), `e`, `l`, `l`, `o`]
	assert tb.get_line_bytes(1) == ?[]u8(none)
}


