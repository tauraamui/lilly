module draw

import term.ui as tui

pub struct Event {
	tui.Event
}

pub struct Config {
pub:
	render_debug bool
	user_data    voidptr
	frame_fn     fn (voidptr)        @[required]
	event_fn     fn (Event, voidptr) @[required]

	capture_events       bool
	use_alternate_buffer bool = true
}

pub struct Color {
pub:
	r u8
	g u8
	b u8
}

pub type Runner = fn () !

pub interface Drawer {
mut:
	draw_text(x int, y int, text string)
	write(c string)
	draw_rect(x int, y int, width int, height int)
	draw_point(x int, y int)
}

pub interface Colorer {
mut:
	set_color(c Color)
	set_bg_color(c Color)
	reset_color()
	reset_bg_color()
}

pub interface Renderer {
	Drawer
	Colorer
}

pub interface Contextable {
	Renderer
mut:
	render_debug() bool
	rate_limit_draws() bool
	window_width() int
	window_height() int

	set_cursor_position(x int, y int)

	bold()

	reset()

//	run() !
	clear()
	flush()
}
