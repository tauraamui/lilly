module draw

import sokol
import sokol.sapp
import sokol.gfx
import sokol.sgl
import fontstash
import sokol.sfons

struct Context{
	ref         sapp.Desc
	frame_cb    fn (v voidptr)
	pass_action gfx.PassAction
	fons        &fontstash.Context = unsafe { nil }
}

pub fn new_context(cfg Config) &Contextable {
	return Context{
		frame_cb: cfg.frame_fn
		ref: sapp.Desc{
			user_data: cfg.user_data
			init_userdata_cb: fn (v voidptr) {
				desc := sapp.create_desc()
				gfx.setup(&desc)
				s := &sgl.Desc{}
				sgl.setup(s)
			}
			frame_userdata_cb: fn [cfg] (v voidptr) {
				cfg.frame_fn(v)
				gfx.begin_default_pass(gfx.PassAction{}, sapp.width(), sapp.height())
				sgl.draw()
				gfx.end_pass()
				gfx.commit()
			}
			window_title: "lilly".str
			width: 800
			height: 600
			high_dpi: true
		}
	}
}

fn (mut ctx Context) window_width() int { return sapp.width() }

fn (mut ctx Context) window_height() int { return sapp.height() }

fn (mut ctx Context) set_cursor_position(x int, y int) {}

fn (mut ctx Context) draw_text(x int, y int, text string) {}

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
	sapp.run(&ctx.ref)
}

fn (mut ctx Context) clear() {}

fn (mut ctx Context) flush() {}
