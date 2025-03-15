module ui

import lib.buffer
import lib.draw

pub struct BufferView {
	buf &buffer.Buffer = unsafe { nil }
}

pub fn BufferView.new(buf &buffer.Buffer) BufferView {
	return BufferView{ buf: buf }
}

pub fn (buf_view BufferView) draw(mut ctx draw.Contextable, x int, y int, width int, height int) {
	// if buf_view.buf == unsafe { nil } { return }
	ctx.set_bg_color(r: 100, g: 100, b: 225)
	ctx.draw_rect(x + 1, y + 1, width, height)
	ctx.reset_bg_color()
}
