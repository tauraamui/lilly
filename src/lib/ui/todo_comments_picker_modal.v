module ui

import lib.draw
import lib.buffer

pub struct TodoCommentPickerModal {
mut:
	open bool
	from int
pub:
	matches []buffer.Match
}

pub fn TodoCommentPickerModal.new(matches []buffer.Match) TodoCommentPickerModal {
	return TodoCommentPickerModal{
		matches: matches
	}
}

pub fn (mut todo_comment_picker_modal TodoCommentPickerModal) open() {
	todo_comment_picker_modal.open = true
}

pub fn (todo_comment_picker_modal TodoCommentPickerModal) is_open() bool { return todo_comment_picker_modal.open }

pub fn (mut todo_comment_picker_modal TodoCommentPickerModal) close() {
	todo_comment_picker_modal.open = false
}

pub fn (mut todo_comment_picker_modal TodoCommentPickerModal) draw(mut ctx draw.Contextable) {
	defer { ctx.reset_bg_color() }
	ctx.set_color(r: 245, g: 245, b: 245) // set font colour
	ctx.set_bg_color(r: 15, g: 15, b: 15)

	mut y_offset := 1
	debug_mode_str := if ctx.render_debug() { " ***RENDER DEBUG MODE ***" } else { "" }

	ctx.draw_text(1, y_offset, "=== ${debug_mode_str} TODO COMMENTS PICKER ${debug_mode_str} ===") // draw header
	y_offset += 1
	y_offset += todo_comment_picker_modal.draw_scrollable_list(mut ctx, y_offset, todo_comment_picker_modal.matches)
}

fn (mut todo_comment_picker_modal TodoCommentPickerModal) resolve_to() int {
	matches := todo_comment_picker_modal.matches
	mut to := todo_comment_picker_modal.from + max_height
	if to > matches.len {
		to = matches.len
	}
	return to
}

pub fn (mut todo_comment_picker_modal TodoCommentPickerModal) draw_scrollable_list(mut ctx draw.Contextable, y_offset int, list []buffer.Match) int {
	ctx.reset_bg_color()
	ctx.set_bg_color(r: 15, g: 15, b: 15)
	ctx.draw_rect(1, y_offset, ctx.window_width(), y_offset + max_height - 1)
	to := todo_comment_picker_modal.resolve_to()
	for i := todo_comment_picker_modal.from; i < to; i++ {
		ctx.set_bg_color(r: 15, g: 15, b: 15)
		list_item_content := "${list[i].file_path}:${list[i].pos.y}:${list[i].pos.x}"
		ctx.draw_text(1, y_offset + (i - todo_comment_picker_modal.from), list_item_content)
	}
	return 100
}

pub fn (mut todo_comment_picker_modal TodoCommentPickerModal) on_key_down(e draw.Event) Action {
	match e.code {
		.escape {
			return Action{ op: .close_op }
		}
		else {}
	}
	return Action{ op: .no_op }
}

