module draw

import gg
import gx
import math
import os

struct Context {
	user_data voidptr
	frame_cb fn (v voidptr)
mut:
	gg      &gg.Context = unsafe { nil }
	txt_cfg gx.TextCfg
}

pub fn new_context(cfg Config) &Contextable {
	mut ctx := &Context{
		user_data: cfg.user_data
		frame_cb: cfg.frame_fn
	}
	ctx.gg = gg.new_context(
				width: 800
				height: 600
				create_window: true
				window_title: "Lilly Editor"
				user_data: ctx
				bg_color: gx.white
				font_path: os.resource_abs_path("../experiment/RobotoMono-Regular.ttf")
				frame_fn: frame
			)
	return ctx
}

fn frame(mut ctx Context) {
	ctx.gg.begin()
	width := gg.window_size().width
	mut scale_factor := math.round(f32(width) / 800)
	if scale_factor <= 0 { scale_factor = 1 }
	ctx.txt_cfg = gx.TextCfg{
		size: 16 * int(scale_factor)
	}
	ctx.frame_cb(ctx.user_data)
	ctx.gg.end()
}

fn (mut ctx Context) rate_limit_draws() bool { return false }

fn (mut ctx Context) window_width() int { return gg.window_size().width }

fn (mut ctx Context) window_height() int { return gg.window_size().height }

fn (mut ctx Context) set_cursor_position(x int, y int) {}

fn (mut ctx Context) draw_text(x int, y int, text string) {
	ctx.gg.draw_text(x * 16, y * 16, text, ctx.txt_cfg)
}

fn (mut ctx Context) write(c string) {}

fn (mut ctx Context) draw_rect(x int, y int, width int, height int) {}

fn (mut ctx Context) draw_point(x int, y int) {}

fn (mut ctx Context) bold() {}

fn (mut ctx Context) set_color(c Color) {}

fn (mut ctx Context) set_bg_color(c Color) {}

fn (mut ctx Context) reset_color() {}

fn (mut ctx Context) reset_bg_color() {}

fn (mut ctx Context) reset() {}

fn (mut ctx Context) run() ! {
	ctx.gg.run()
}

fn (mut ctx Context) clear() {}

fn (mut ctx Context) flush() {}

