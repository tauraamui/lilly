module ui

import lib.buffer
import lib.draw

struct DrawnText {
	x int
	y int
	data string
}

fn test_buffer_view_draws_lines_0_to_max_height() {
	mut drawn_text := []DrawnText{}
	mut ref := &drawn_text
	mut mock_ctx := MockContextable{
		on_draw_cb: fn [mut ref] (x int, y int, text string) {
			ref << DrawnText{ x: x, y: y, data: text }
		}
	}
	mut buf      := buffer.Buffer.new("", false)
	for i in 0..20 { buf.lines << "${i} This is line ${i} in the document" }
	buf_view := BufferView.new(&buf)

	x := 0
	y := 0
	width := 100
	height := 10
	from_line_num := 0

	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num)

	assert drawn_text == [
		DrawnText{ x: 1, y: 1, data:  "0 This is line 0 in the document" },
		DrawnText{ x: 1, y: 2, data:  "1 This is line 1 in the document" },
		DrawnText{ x: 1, y: 3, data:  "2 This is line 2 in the document" },
		DrawnText{ x: 1, y: 4, data:  "3 This is line 3 in the document" },
		DrawnText{ x: 1, y: 5, data:  "4 This is line 4 in the document" },
		DrawnText{ x: 1, y: 6, data:  "5 This is line 5 in the document" },
		DrawnText{ x: 1, y: 7, data:  "6 This is line 6 in the document" },
		DrawnText{ x: 1, y: 8, data:  "7 This is line 7 in the document" },
		DrawnText{ x: 1, y: 9, data:  "8 This is line 8 in the document" },
		DrawnText{ x: 1, y: 10, data: "9 This is line 9 in the document" }
	]
}

fn test_buffer_view_draws_lines_10_to_max_height() {
	mut drawn_text := []DrawnText{}
	mut ref := &drawn_text
	mut mock_ctx := MockContextable{
		on_draw_cb: fn [mut ref] (x int, y int, text string) {
			ref << DrawnText{ x: x, y: y, data: text }
		}
	}
	mut buf      := buffer.Buffer.new("", false)
	for i in 0..20 { buf.lines << "${i} This is line ${i} in the document" }
	buf_view := BufferView.new(&buf)

	x := 0
	y := 0
	width := 100
	height := 10
	from_line_num := 10

	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num)

	assert drawn_text == [
		DrawnText{ x: 1, y: 1, data:  "10 This is line 10 in the document" },
		DrawnText{ x: 1, y: 2, data:  "11 This is line 11 in the document" },
		DrawnText{ x: 1, y: 3, data:  "12 This is line 12 in the document" },
		DrawnText{ x: 1, y: 4, data:  "13 This is line 13 in the document" },
		DrawnText{ x: 1, y: 5, data:  "14 This is line 14 in the document" },
		DrawnText{ x: 1, y: 6, data:  "15 This is line 15 in the document" },
		DrawnText{ x: 1, y: 7, data:  "16 This is line 16 in the document" },
		DrawnText{ x: 1, y: 8, data:  "17 This is line 17 in the document" },
		DrawnText{ x: 1, y: 9, data:  "18 This is line 18 in the document" },
		DrawnText{ x: 1, y: 10, data: "19 This is line 19 in the document" }
	]
}

fn test_buffer_view_draws_lines_0_to_max_height_min_x_is_6() {
	mut drawn_text := []DrawnText{}
	mut ref := &drawn_text
	mut mock_ctx := MockContextable{
		on_draw_cb: fn [mut ref] (x int, y int, text string) {
			ref << DrawnText{ x: x, y: y, data: text }
		}
	}
	mut buf      := buffer.Buffer.new("", false)
	for i in 0..20 { buf.lines << "${i} This is line ${i} in the document" }
	mut buf_view := BufferView.new(&buf)
	buf_view.min_x = 6

	x := 0
	y := 0
	width := 100
	height := 10
	from_line_num := 0

	buf_view.draw(mut mock_ctx, x, y, width, height, from_line_num)

	assert drawn_text == [
		DrawnText{ x: 1, y: 1, data:  " is line 0 in the document" },
		DrawnText{ x: 1, y: 2, data:  " is line 1 in the document" },
		DrawnText{ x: 1, y: 3, data:  " is line 2 in the document" },
		DrawnText{ x: 1, y: 4, data:  " is line 3 in the document" },
		DrawnText{ x: 1, y: 5, data:  " is line 4 in the document" },
		DrawnText{ x: 1, y: 6, data:  " is line 5 in the document" },
		DrawnText{ x: 1, y: 7, data:  " is line 6 in the document" },
		DrawnText{ x: 1, y: 8, data:  " is line 7 in the document" },
		DrawnText{ x: 1, y: 9, data:  " is line 8 in the document" },
		DrawnText{ x: 1, y: 10, data: " is line 9 in the document" }
	]
}


struct MockContextable {
mut:
	on_draw_cb fn (x int, y int, text string)
}

fn (mockctx MockContextable) render_debug() bool { return false }

fn (mockctx MockContextable) rate_limit_draws() bool {
	return false
}

fn (mockctx MockContextable) window_width() int {
	return 0
}

fn (mockctx MockContextable) window_height() int {
	return 0
}

fn (mockctx MockContextable) set_cursor_position(x int, y int) {}

fn (mut mockctx MockContextable) draw_text(x int, y int, text string) {
	mockctx.on_draw_cb(x, y, text)
}

fn (mockctx MockContextable) write(c string) {}

fn (mockctx MockContextable) draw_rect(x int, y int, width int, height int) {}

fn (mockctx MockContextable) draw_point(x int, y int) {}

fn (mockctx MockContextable) set_color(c draw.Color) {}

fn (mockctx MockContextable) set_bg_color(c draw.Color) {}

fn (mockctx MockContextable) revert_bg_color() {}

fn (mockctx MockContextable) reset_color() {}

fn (mockctx MockContextable) reset_bg_color() {}

fn (mockctx MockContextable) bold() {}

fn (mockctx MockContextable) reset() {}

fn (mockctx MockContextable) run() ! {}

fn (mockctx MockContextable) clear() {}

fn (mockctx MockContextable) flush() {}
