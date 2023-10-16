module main

import term.ui as tui

struct Status {
	mode      Mode
	cursor_x  int
	cursor_y  int
	file_name string
}

fn draw_status_line(mut ctx tui.Context, status Status) {
	defer { ctx.reset() }
	ctx.set_bg_color(r: 25, g: 25, b: 25)
	ctx.draw_rect(12, ctx.window_height - 1, ctx.window_width, ctx.window_height - 1)
	mut offset := status.mode.draw(mut ctx, 1, ctx.window_height - 1) + 2
	if status.file_name.len > 0 { offset += draw_file_name_segment(mut ctx, offset, ctx.window_height - 1, status.file_name) }
	paint_shape_text(mut ctx, 1 + offset, ctx.window_height - 1, Color{ 25, 25, 25 }, "${slant_left_flat_top}")
}

fn draw_file_name_segment(mut ctx tui.Context, x int, y int, file_name string) int {
	paint_shape_text(mut ctx, x, y, Color{ 86, 86, 86 }, "${slant_left_flat_top}${block}")
	mut offset := 2
	paint_text_on_background(mut ctx, x + offset, y, Color{ 86, 86, 86 }, Color{ 230, 230, 230 }, file_name)
	offset += file_name.len
	paint_shape_text(mut ctx, x + offset, y, Color{ 86, 86, 86 }, "${block}${slant_right_flat_bottom}")
	offset += 1
	return offset
}
