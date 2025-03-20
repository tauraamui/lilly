module ui

import lib.buffer
import lib.draw

pub struct BufferView {
	buf   &buffer.Buffer = unsafe { nil }
mut:
	min_x int
}

pub fn BufferView.new(buf &buffer.Buffer) BufferView {
	return BufferView{ buf: buf }
}

pub fn (buf_view BufferView) draw(
	mut ctx draw.Contextable,
	x int, y int,
	width int, height int,
	from_line_num int,
	cursor_y_pos int
) {
	if buf_view.buf == unsafe { nil } { return }

	// NOTE(tauraamui) [20/03/2025]: this is just here to be invoked in the test for now
	ctx.draw_rect(x, y, width, 1)

	mut screenspace_x_offset := 1 + buf_view.buf.num_of_lines().str().runes().len
	mut screenspace_y_offset := 1
	for document_line_num, line in buf_view.buf.line_iterator() {
		// if we haven't reached the line to render in the document yet, skip this
		if document_line_num < from_line_num { continue }

		// draw line number
		draw_line_number(mut ctx, x + screenspace_x_offset, y + screenspace_y_offset, document_line_num)

		// draw the line of text, offset by the position of the buffer view
		draw_text_line(mut ctx, x + screenspace_x_offset + 1, y + screenspace_y_offset, line, buf_view.min_x, width)

		screenspace_y_offset += 1
		// detect if number of lines drawn would exceed current height of view
		if screenspace_y_offset > height { return }
	}
}

const line_num_fg_color = draw.Color{ r: 117, g: 118, b: 120 }

fn draw_line_number(mut ctx draw.Contextable, x int, y int, line_num int) {
	defer { ctx.reset_color() }
	ctx.set_color(line_num_fg_color)

	mut line_num_str := "${line_num + 1}"
	ctx.draw_text(x - line_num_str.runes().len, y, line_num_str)
}

fn draw_text_line(mut ctx draw.Contextable, x int, y int, line string, min_x int, width int) {
	if min_x >= line.runes().len { ctx.draw_text(x, y, ""); return }

	line_past_min_x := line.runes()[min_x..].string()

	ctx.draw_text(x, y, line_past_min_x)
}

