module draw

import gg
import gx
import math
import os

struct Context {
	user_data voidptr
	frame_cb  fn (v voidptr) @[required]
mut:
	gg                         &gg.Context = unsafe { nil }
	txt_cfg                    gx.TextCfg
	foreground_color           Color
	background_color           Color
	text_draws_since_last_pass int
}

pub fn new_context(cfg Config) (&Contextable, Runner) {
	mut ctx := &Context{
		user_data: cfg.user_data
		frame_cb:  cfg.frame_fn
	}
	ctx.gg = gg.new_context(
		width:         800
		height:        600
		create_window: true
		window_title:  'Lilly Editor'
		user_data:     ctx
		bg_color:      gx.white
		font_path:     os.resource_abs_path('../experiment/RobotoMono-Regular.ttf')
		frame_fn:      frame
	)
	return ctx, unsafe { ctx.run_wrapper }
}

const font_size = 16

fn (mut ctx Context) run_wrapper() ! {
    ctx.gg.run()
}

fn (mut ctx Context) render_debug() bool {
    return true
}

fn frame(mut ctx Context) {
	width := gg.window_size().width
	mut scale_factor := gg.dpi_scale()
	if scale_factor <= 0 {
		scale_factor = 1
	}
	ctx.txt_cfg = gx.TextCfg{
		size: draw.font_size * int(scale_factor)
	}
	ctx.frame_cb(ctx.user_data)
	if ctx.text_draws_since_last_pass < 1000 {
		ctx.text_draws_since_last_pass = 0
		ctx.gg.end()
	}
}

fn (mut ctx Context) rate_limit_draws() bool {
	return false
}

fn (mut ctx Context) window_width() int {
	return gg.window_size().width
}

fn (mut ctx Context) window_height() int {
	return gg.window_size().height
}

fn (mut ctx Context) set_cursor_position(x int, y int) {}

fn (mut ctx Context) draw_text(x int, y int, text string) {
	// this offsetting stuff is a bit mental but seems to be correct
	if ctx.text_draws_since_last_pass == 0 {
		ctx.gg.begin()
	}
	ctx.gg.draw_text((draw.font_size / 2) + x - (draw.font_size / 2), (y * draw.font_size) - draw.font_size,
		text, ctx.txt_cfg)
	if ctx.text_draws_since_last_pass >= 1000 {
		ctx.gg.end(how: .passthru)
		ctx.text_draws_since_last_pass = 0
		return
	}
	ctx.text_draws_since_last_pass += 1
}

fn (mut ctx Context) write(c string) {}

fn (mut ctx Context) draw_rect(x int, y int, width int, height int) {
	c := ctx.background_color
	ctx.gg.draw_rect_filled(x, y - 100, width, height / 16, gx.rgb(c.r, c.g, c.b))
}

fn (mut ctx Context) draw_point(x int, y int) {}

fn (mut ctx Context) bold() {}

fn (mut ctx Context) set_color(c Color) {
	ctx.foreground_color = c
}

fn (mut ctx Context) set_bg_color(c Color) {
	ctx.background_color = c
}

fn (mut ctx Context) reset_color() {
	ctx.foreground_color = Color{}
}

fn (mut ctx Context) reset_bg_color() {}

fn (mut ctx Context) reset() {
	ctx.foreground_color = Color{}
	ctx.background_color = Color{}
}

fn (mut ctx Context) run() ! {
	ctx.gg.run()
}

fn (mut ctx Context) clear() {
	ctx.gg.begin()
	ctx.gg.end()
}

fn (mut ctx Context) flush() {}
