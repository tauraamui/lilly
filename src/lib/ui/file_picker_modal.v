module ui

import lib.draw

@[noinit]
pub struct FilePickerModal {
	file_paths []string
pub mut:
	special_mode bool // NOTE(tsauraamui) [14/02/2025] will likely deprecate or change this for now
mut:
	open bool
	current_sel_id   int
	list_render_from int
	search           FileSearch
}

struct FileSearch {
mut:
	query    string
	cursor_x int
}

fn (mut file_search FileSearch) put_char(c string) {
	first := file_search.query[..file_search.cursor_x]
	last := file_search.query[file_search.cursor_x..]
	file_search.query = '${first}${c}${last}'
	file_search.cursor_x += 1
}

fn (mut file_search FileSearch) backspace() {
	if file_search.cursor_x == 0 {
		return
	}
	first := file_search.query[..file_search.cursor_x - 1]
	last := file_search.query[file_search.cursor_x..]
	file_search.query = '${first}${last}'
	file_search.cursor_x -= 1
	if file_search.cursor_x < 0 {
		file_search.cursor_x = 0
	}
}

pub fn FilePickerModal.new(file_paths []string) FilePickerModal {
	return FilePickerModal{
		file_paths: file_paths
	}
}

pub fn (mut f_picker FilePickerModal) open() {
	f_picker.open = true
}

pub fn (f_picker FilePickerModal) draw(mut ctx draw.Contextable) {

	defer { ctx.reset_bg_color() }
	ctx.set_color(r: 245, g: 245, b: 245)
	ctx.set_bg_color(r: 15, g: 15, b: 15)
	mut y_offset := 1
	debug_mode_str := if ctx.render_debug() { " *** RENDER DEBUG MODE ***" } else { "" }
	special_mode_str := if f_picker.special_mode { " - SPECIAL MODE" } else { "" }
	ctx.draw_text(1, y_offset, "=== ${debug_mode_str} FILE PICKER${special_mode_str} ${debug_mode_str} ===")
	y_offset += 1
	ctx.set_cursor_position(1, y_offset + f_picker.current_sel_id - f_picker.list_render_from)
	y_offset += f_picker.draw_scrollable_list(mut ctx, y_offset, file_finder_modal.file_paths)
	ctx.set_bg_color(r: 153, g: 95, b: 146)
	ctx.draw_rect(1, y_offset, ctx.window_width(), y_offset)
	search_label := 'SEARCH:'
	ctx.draw_text(1, y_offset, search_label)
	ctx.draw_text(1 + utf8_str_visible_length(search_label) + 1, y_offset, file_finder_modal.search.query)
}

pub fn (f_picker FilePickerModal) is_open() bool { return f_picker.open }

pub fn (mut f_picker FilePickerModal) close() {
	f_picker.open = false
}

