module draw

import sokol
import sokol.sapp
import sokol.gfx
import sokol.sgl
import fontstash
import sokol.sfons
import os

struct Context{
	state       &State
	ref         sapp.Desc
}

struct State {
mut:
	user_data    voidptr
	frame_cb    fn (v voidptr)
	pass_action gfx.PassAction
	fons        &fontstash.Context = unsafe { nil }
	font_normal int
	inited      bool
}

const black = sfons.rgba(0, 0, 0, 255)

pub fn new_context(cfg Config) &Contextable {
	mut color_action := gfx.ColorAttachmentAction{
		load_action: .clear
		clear_value: gfx.Color{
			r: 1.0
			g: 1.0
			b: 1.0
			a: 1.0
		}
	}
	mut pass_action := gfx.PassAction{}
	pass_action.colors[0] = color_action
	state := &State{
		pass_action: pass_action
		user_data: cfg.user_data
	}
	return &Context{
		state: state
		ref: sapp.Desc{
			user_data: state
			init_userdata_cb: fn (mut state State) {
				desc := sapp.create_desc()
				gfx.setup(&desc)
				s := &sgl.Desc{}
				sgl.setup(s)
				state.fons = sfons.create(512, 512, 1)
				if bytes := os.read_bytes(os.resource_abs_path("../experiment/RobotoMono-Regular.ttf")) {
					println("loaded font: ${bytes.len}")
					state.font_normal = state.fons.add_font_mem("sans", bytes, false)
				}
			}
			frame_userdata_cb: fn [cfg] (mut state State) {
				mut fons := state.fons
				if !state.inited {
					fons.clear_state()
					sgl.defaults()
					sgl.matrix_mode_projection()
					sgl.ortho(0.0, f32(sapp.width()), f32(sapp.height()), 0.0, -1.0, 1.0)
					fons.set_font(state.font_normal)
					fons.set_color(black)
					fons.set_size(18)
					state.inited = true
				}
				cfg.frame_fn(state.user_data)
				/*
				gfx.begin_default_pass(&state.pass_action, sapp.width(), sapp.height())
				sgl.draw()
				gfx.end_pass()
				gfx.commit()
				*/
			}
			window_title: "lilly".str
			width: 800
			height: 600
			high_dpi: true
		}
	}
}

fn (mut ctx Context) rate_limit_draws() bool { return false }

fn (mut ctx Context) window_width() int { return sapp.width() }

fn (mut ctx Context) window_height() int { return sapp.height() }

fn (mut ctx Context) set_cursor_position(x int, y int) {}

fn (mut ctx Context) draw_text(x int, y int, text string) {
	ctx.state.fons.draw_text(x, y, text)
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
	sapp.run(&ctx.ref)
}

fn (mut ctx Context) clear() {
	gfx.begin_default_pass(&ctx.state.pass_action, sapp.width(), sapp.height())
	sgl.draw()
	gfx.end_pass()
	gfx.commit()
}

fn (mut ctx Context) flush() {
	sfons.flush(ctx.state.fons)
}
