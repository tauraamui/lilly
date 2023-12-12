module draw

import term.ui as tui

pub interface Context {
mut:
	window_width int
	window_height int

	set_cursor_position(x int, y int)

	draw_text(x int, y int, text string)
	write(c string)
	draw_rect(x int, y int, width int, height int)
	draw_point(x int, y int)

	bold()

	set_color(c tui.Color)
	set_bg_color(c tui.Color)
	reset_color()
	reset_bg_color()
	reset()

	run() !
	clear()
	flush()
}
