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
		// if we haven't reached the line to render in the document yet, skip this
		if document_line_num < from_line_num { continue }

		// draw the line of text, offset by the position of the buffer view
		draw_text_line(mut ctx, x + 1, y + screenspace_y_offset, line, 0, width)

		screenspace_y_offset += 1
		// detect if number of lines drawn would exceed current height of view
		if screenspace_y_offset > height { return }
	}
}

fn draw_text_line(mut ctx draw.Contextable, x int, y int, line string, min_x int, width int) {
	ctx.draw_text(x, y, line)
}

