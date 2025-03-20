// Copyright 2025 Google LLC
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

struct Context {
	render_debug bool
mut:
	ref &tui.Context
}

type Runner = fn () !

pub fn new_context(cfg Config) (&Contextable, Runner) {
	ctx := Context{
		render_debug: cfg.render_debug
		ref: tui.init(
			user_data: cfg.user_data
			event_fn:  fn [cfg] (e &tui.Event, app voidptr) {
				cfg.event_fn(Event{e}, app)
			}
			frame_fn:             cfg.frame_fn
			capture_events:       cfg.capture_events
			use_alternate_buffer: cfg.use_alternate_buffer
		)
	}
	return ctx, unsafe { ctx.run }
}

fn (mut ctx Context) rate_limit_draws() bool {
	return true
}

fn (mut ctx Context) render_debug() bool { return ctx.render_debug }

fn (mut ctx Context) window_width() int {
	return ctx.ref.window_width
}

fn (mut ctx Context) window_height() int {
	return ctx.ref.window_height
}

fn (mut ctx Context) set_cursor_position(x int, y int) {
	ctx.ref.set_cursor_position(x, y)
}

fn (mut ctx Context) draw_text(x int, y int, text string) {
	ctx.ref.draw_text(x, y, text)
}

fn (mut ctx Context) write(c string) {
	ctx.ref.write(c)
}

fn (mut ctx Context) draw_rect(x int, y int, width int, height int) {
	ctx.ref.draw_rect(x, y, width, height)
}

fn (mut ctx Context) draw_point(x int, y int) {
	ctx.ref.draw_point(x, y)
}

fn (mut ctx Context) bold() {
	ctx.ref.bold()
}

fn (mut ctx Context) set_color(c Color) {
	ctx.ref.set_color(tui.Color{ r: c.r, g: c.g, b: c.b })
}

fn (mut ctx Context) set_bg_color(c Color) {
	ctx.ref.set_bg_color(tui.Color{ r: c.r, g: c.g, b: c.b })
}

fn (mut ctx Context) reset_color() {
	ctx.ref.reset_color()
}

fn (mut ctx Context) reset_bg_color() {
	ctx.ref.reset_bg_color()
}

fn (mut ctx Context) reset() {
	ctx.ref.reset()
}

fn (mut ctx Context) run() ! {
	return ctx.ref.run()
}

fn (mut ctx Context) clear() {
	ctx.ref.clear()
}

fn (mut ctx Context) flush() {
	ctx.ref.flush()
}
