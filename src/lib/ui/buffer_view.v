module ui

import lib.buffer
import lib.draw

pub struct BufferView {
	buf &buffer.Buffer = unsafe { nil }
}

pub fn BufferView.new(buf &buffer.Buffer) BufferView {
	return BufferView{ buf: buf }
}

pub fn (buf_view BufferView) draw(
	mut ctx draw.Contextable,
	x int, y int,
	width int, height int,
	from_line_num int
) {
	if buf_view.buf == unsafe { nil } { return }

	mut screenspace_y_offset := 1
	for document_line_num, line in buf_view.buf.line_iterator() {
		if document_line_num < from_line_num { continue }
		ctx.draw_text(x + 1, y + screenspace_y_offset, line)
		screenspace_y_offset += 1
		if screenspace_y_offset > height { return }
	}
}

