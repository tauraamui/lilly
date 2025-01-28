module main

import log
import lib.draw

struct TodoCommentFinderModal {
	log log.Log
	file_paths []string
pub:
	title       string
	file_path   string
	@[required]
	close_fn    ?fn()
}

fn (mut todo_comment_finder_modal TodoCommentFinderModal) draw(mut ctx draw.Contextable) {
	defer { ctx.reset_bg_color() }
	ctx.set_color(r: 245, g: 245, b: 245) // set font colour
	ctx.set_bg_color(r: 15, g: 15, b: 15)

	mut y_offset := 1
	debug_mode_str := if ctx.render_debug() { " ***RENDER DEBUG MODE ***" } else { "" }

	ctx.draw_text(1, y_offset, "=== ${debug_mode_str} ${todo_comment_finder_modal.title} ${debug_mode_str} ===") // draw header
	y_offset += 1
	ctx.draw_rect(1, y_offset, ctx.window_width(), y_offset + max_height)
}

fn (mut todo_comment_finder_modal TodoCommentFinderModal) on_key_down(e draw.Event, mut root Root) {
	match e.code {
		.escape {
			close_fn := todo_comment_finder_modal.close_fn or { return }
			close_fn()
		}
		else {}
	}
}

