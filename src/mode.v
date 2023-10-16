module main

import term.ui as tui

enum Mode as u8 {
	normal
	visual
	insert
	command
}

fn (mode Mode) draw(mut ctx tui.Context, x int, y int) int {
	defer { ctx.reset() }
	label := mode.str()
	status_line_y := y
	status_line_x := x
	status_color := mode.color()
	mut offset := 0
	paint_shape_text(mut ctx, status_line_x + offset, status_line_y, status_color, "${left_rounded}${block}")
	offset += 2
	paint_text_on_background(mut ctx, status_line_x + offset, status_line_y, status_color, Color{ 0, 0, 0}, label)
	offset += label.len
	paint_shape_text(mut ctx, status_line_x + offset, status_line_y, status_color, "${block}${slant_right_flat_bottom}")
	return status_line_x + offset
}

fn (mode Mode) color() Color {
	return match mode {
		.normal { status_green }
		.visual { status_lilac }
		.insert { status_orange }
		.command { status_cyan }
	}
}

fn (mode Mode) str() string {
	return match mode {
		.normal  { "NORMAL"  }
		.visual  { "VISUAL"  }
		.insert  { "INSERT"  }
		.command { "COMMAND" }
	}
}

