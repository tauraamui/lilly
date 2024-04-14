module draw

import term.ui as tui

pub struct Event {
	tui.Event
}

pub struct Config {
pub:
	user_data voidptr
	frame_fn  fn (voidptr)        @[required]
	event_fn  fn (Event, voidptr) @[required]

	capture_events       bool
	use_alternate_buffer bool = true
}

pub struct Color {
pub:
	r u8
	g u8
	b u8
}

pub interface Contextable {
mut:
	rate_limit_draws() bool
	window_width() int
	window_height() int

	set_cursor_position(x int, y int)

	draw_text(x int, y int, text string)
	write(c string)
	draw_rect(x int, y int, width int, height int)
	draw_point(x int, y int)

	bold()

	set_color(c Color)
	set_bg_color(c Color)
	reset_color()
	reset_bg_color()
	reset()

	run() !
	clear()
	flush()
}
