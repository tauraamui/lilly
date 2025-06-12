// Copyright 2024 The Lilly Editor contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

module draw

import term.ui as tui
import lib.theme as themelib

pub struct Event {
	tui.Event
}

pub struct Config {
pub:
	render_debug bool
	default_bg_color ?tui.Color
	theme            themelib.Theme
	user_data        voidptr
	frame_fn         fn (voidptr)        @[required]
	event_fn         fn (Event, voidptr) @[required]

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
	theme() themelib.Theme
mut:
	render_debug() bool
	rate_limit_draws() bool
	window_width() int
	window_height() int

	set_cursor_position(x int, y int)
	set_cursor_to_block()
	set_cursor_to_underline()
	set_cursor_to_vertical_bar()
	show_cursor()
	hide_cursor()

	bold()
	set_style(s Style)
	clear_style()

	reset()

//	run() !
	clear()
	flush()
}

