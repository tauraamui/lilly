module ui

import lib.draw
import lib.buffer

pub struct TodoCommentPickerModal {
mut:
	open           bool
	from           int
	current_sel_id int
pub:
	matches []buffer.Match
}

pub fn TodoCommentPickerModal.new(matches []buffer.Match) TodoCommentPickerModal {
	return TodoCommentPickerModal{
		matches: matches
	}
}

pub fn (mut tc_picker TodoCommentPickerModal) open() {
	tc_picker.open = true
}

pub fn (tc_picker TodoCommentPickerModal) is_open() bool { return tc_picker.open }

pub fn (mut tc_picker TodoCommentPickerModal) close() {
	tc_picker.open = false
}

pub fn (mut tc_picker TodoCommentPickerModal) draw(mut ctx draw.Contextable) {
	defer { ctx.reset_bg_color() }
	ctx.set_color(r: 245, g: 245, b: 245) // set font colour
	ctx.set_bg_color(r: 15, g: 15, b: 15)

	mut y_offset := 1
	debug_mode_str := if ctx.render_debug() { " ***RENDER DEBUG MODE ***" } else { "" }

	ctx.draw_text(1, y_offset, "=== ${debug_mode_str} TODO COMMENTS PICKER ${debug_mode_str} ===") // draw header
	y_offset += 1
	y_offset += tc_picker.draw_scrollable_list(mut ctx, y_offset, tc_picker.matches)
}

fn (mut tc_picker TodoCommentPickerModal) resolve_to() int {
	matches := tc_picker.matches
	mut to := tc_picker.from + max_height
	if to > matches.len {
		to = matches.len
	}
	return to
}

pub fn (mut tc_picker TodoCommentPickerModal) draw_scrollable_list(mut ctx draw.Contextable, y_offset int, list []buffer.Match) int {
	ctx.reset_bg_color()
	ctx.set_bg_color(r: 15, g: 15, b: 15)
	ctx.draw_rect(1, y_offset, ctx.window_width(), y_offset + max_height - 1)
	to := tc_picker.resolve_to()
	for i := tc_picker.from; i < to; i++ {
		ctx.set_bg_color(r: 15, g: 15, b: 15)
		list_item_content := "${list[i].file_path}:${list[i].pos.y}:${list[i].pos.x} ${list[i].contents}"
		ctx.draw_text(1, y_offset + (i - tc_picker.from), list_item_content)
	}
	return 100
}

pub fn (mut tc_picker TodoCommentPickerModal) on_key_down(e draw.Event) Action {
	match e.code {
		.escape {
			return Action{ op: .close_op }
		}
		.enter {
			return tc_picker.match_selected()
		}
		else {}
	}
	return Action{ op: .no_op }
}

fn (mut tc_picker TodoCommentPickerModal) match_selected() Action {
	matches := tc_picker.matches
	selected_match := matches[tc_picker.current_sel_id]
	return Action{}
}

