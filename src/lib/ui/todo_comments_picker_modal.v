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
	ctx.set_cursor_position(1, y_offset + tc_picker.current_sel_id - tc_picker.from)
	y_offset += tc_picker.draw_scrollable_list(mut ctx, y_offset, tc_picker.matches)
	ctx.set_bg_color(r: 153, g: 95, b: 146)
	ctx.draw_rect(1, y_offset, ctx.window_width(), y_offset)
	search_label := "SEARCH:"
	ctx.draw_text(1, y_offset, search_label)
	// ctx.draw_text(1 + utf8_str_visible_length(search_label) + 1, y_offset, tc_picker.search.query)
	ctx.draw_text(1 + utf8_str_visible_length(search_label) + 1, y_offset, "")
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
		if tc_picker.current_sel_id == i {
			ctx.set_bg_color(r: 53, g: 53, b: 53)
			ctx.draw_rect(1, y_offset + (i - tc_picker.from), ctx.window_width(),
				y_offset + (i - tc_picker.from))
		}
		list_item_content := "${list[i].file_path}:${list[i].pos.y}:${list[i].pos.x} ${list[i].contents}"
		ctx.draw_text(1, y_offset + (i - tc_picker.from), list_item_content)
	}
	return y_offset + (max_height - 2)
}

pub fn (mut tc_picker TodoCommentPickerModal) on_key_down(e draw.Event) Action {
	match e.code {
		.escape {
			return Action{ op: .close_op }
		}
		.down {
			tc_picker.move_selection_down()
		}
		.up {
			tc_picker.move_selection_up()
		}
		.enter {
			return tc_picker.match_selected()
		}
		else {}
	}
	return Action{ op: .no_op }
}

fn (mut tc_picker TodoCommentPickerModal) move_selection_down() {
	matches := tc_picker.matches
	tc_picker.current_sel_id += 1
	to := tc_picker.resolve_to()
	if tc_picker.current_sel_id >= to {
		if matches.len - to > 0 {
			tc_picker.from += 1
		}
	}
	if tc_picker.current_sel_id >= matches.len {
		tc_picker.current_sel_id = matches.len - 1
	}
}

fn (mut tc_picker TodoCommentPickerModal) move_selection_up() {
	tc_picker.current_sel_id -= 1
	if tc_picker.current_sel_id < tc_picker.from {
		tc_picker.from -= 1
	}
	if tc_picker.from < 0 {
		tc_picker.from = 0
	}
	if tc_picker.current_sel_id < 0 {
		tc_picker.current_sel_id = 0
	}
}

fn (mut tc_picker TodoCommentPickerModal) match_selected() Action {
	matches := tc_picker.matches
	selected_match := matches[tc_picker.current_sel_id]
	return Action{ op: .open_file_op, file_path: "${selected_match.file_path}:${selected_match.pos.y}:${selected_match.pos.x}" }
}

