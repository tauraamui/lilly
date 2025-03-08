module ui

import time
import lib.buffer
import lib.draw

struct TestDrawer {
	draw_text_callback fn (x int, y int, text string) @[required]
}

fn (mut drawer TestDrawer) draw_text(x int, y int, text string) {
	if drawer.draw_text_callback == unsafe { nil } { return }
	drawer.draw_text_callback(x, y, text)
}

fn (mut drawer TestDrawer) write(text string) {
	time.sleep(1 * time.millisecond)
}

fn (mut drawer TestDrawer) draw_rect(x int, y int, width int, height int) {
	time.sleep(1 * time.millisecond)
}

fn (mut drawer TestDrawer) draw_point(x int, y int) {
	time.sleep(1 * time.millisecond)
}

fn (mut drawer TestDrawer) render_debug() bool { return false }
fn (mut drawer TestDrawer) set_color(c draw.Color) {}
fn (mut drawer TestDrawer) set_bg_color(c draw.Color) {}
fn (mut drawer TestDrawer) reset_color() {}
fn (mut drawer TestDrawer) reset_bg_color() {}
fn (mut drawer TestDrawer) rate_limit_draws() bool { return false }
fn (mut drawer TestDrawer) window_width() int { return 500 }
fn (mut drawer TestDrawer) window_height() int { return 500 }
fn (mut drawer TestDrawer) set_cursor_position(x int, y int) {}
fn (mut drawer TestDrawer) bold() {}
fn (mut drawer TestDrawer) reset() {}
fn (mut drawer TestDrawer) clear() {}
fn (mut drawer TestDrawer) flush() {}

fn test_todo_comment_modal_rendering_with_match_list_entries() {
	mut drawn_text := []string{}
	mut ref := &drawn_text

	mut mock_drawer := TestDrawer{
		draw_text_callback: fn [mut ref] (x int, y int, text string) { ref << text }
	}

	// NOTE(tauraamui) [07/03/2025]: despite the below example comments having the '-x' exclusion
	//                               flag to exclude them from the match list, it doesn't prevent
	//                               this render test working correctly as the match list is manuallly
	//                               populated here
	mut mock_modal := TodoCommentPickerModal.new([
		buffer.Match{
			file_path: "example-file.txt"
			pos: buffer.Pos{ x: 11, y: 38 },
			contents: "A fake l // -x TODO(tauraamui) [28/02/2025] random comment"
			keyword_loc: 15
			keyword_len: 4
		},
		buffer.Match{
			file_path: "test-file.txt"
			pos: buffer.Pos{ x: 3, y: 112 },
			contents: "// -x TODO(tauraamui) [11/01/2025] blah blah blah blah...!"
		}
	])

	mock_modal.draw(mut mock_drawer)
	assert drawn_text.len > 0
	cleaned_list := drawn_text[1..drawn_text.len - 2].clone()
	assert cleaned_list == [
		"example-file.txt:38:11", " A fake l // -x TODO(tauraamui) [28/02/2025] random comment"
		"test-file.txt:112:3", " // -x TODO(tauraamui) [11/01/2025] blah blah blah blah...!"
	]
}

fn test_todo_comment_modal_enter_returns_currently_selected_match_entry() {
	mut drawn_text := []string{}
	mut ref := &drawn_text

	mut mock_drawer := TestDrawer{
		draw_text_callback: fn [mut ref] (x int, y int, text string) { ref << text }
	}

	mut mock_modal := TodoCommentPickerModal.new([
		buffer.Match{
			file_path: "example-file.txt"
			pos: buffer.Pos{ x: 11, y: 38 },
			contents: "A fake l // -x TODO(tauraamui) [28/02/2025] random comment"
		},
		buffer.Match{
			file_path: "test-file.txt"
			pos: buffer.Pos{ x: 3, y: 112 },
			contents: "// -x TODO(tauraamui) [11/01/2025] blah blah blah blah...!"
		}
	])
}


