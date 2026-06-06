module main

import bobatea as tea
import lib.documents
import lib.petal.theme
import lib.palette

struct EditorModel2 {
	id             int
	file_path      string
	doc_id         int
	theme          theme.Theme
	doc_controller &documents.Controller2
	chord          Chord
mut:
	viewport_width int
	viewport_height int
	top_line int
}

fn EditorModel2.new(l_theme theme.Theme, doc_id int, doc_controller &documents.Controller2) EditorModel2 {
	return EditorModel2{
		doc_id: doc_id
		theme: l_theme
		doc_controller: doc_controller
	}
}

fn (mut m EditorModel2) init() fn () tea.Msg {
	return tea.emit_resize
}

fn (mut m EditorModel2) update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
	if msg is EditorModelKeyMsg {
		match msg.mode {
			.normal {
				return m.normal_mode_update(msg.key_msg)
			}
			.insert {
				return m.insert_mode_update(msg.key_msg)
			}
			else {}
		}
	}

	match msg {
		tea.ResizedMsg {
			m.viewport_width  = msg.window_width // artificially shrunk by parent model EditorWorkspace
			m.viewport_height = msg.window_height
		}
		EditorModelMsg {
			return m.editor_model_update(msg.msg)
		}
		else {}
	}

	return m.clone(), tea.noop_cmd
}

fn (mut m EditorModel2) editor_model_update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
	match msg {
		QueryEditorDataMsg {
			return m.clone(), editor_data(m.data())
		}
		else {}
	}
	return m.clone(), tea.noop_cmd
}

fn (mut m EditorModel2) normal_mode_update(msg tea.KeyMsg) (tea.Model, fn () tea.Msg) {
	match msg.k_type {
		// TODO(tauraamui) [2026-04-06]: implement rune based motions via chords once again
		.runes {
			match msg.string() {
				'h' {
					m.doc_controller.move_cursor_left(m.doc_id)
				}
				'j' {
					m.doc_controller.move_cursor_down(m.doc_id)
				}
				'k' {
					m.doc_controller.move_cursor_up(m.doc_id)
				}
				'l' {
					m.doc_controller.move_cursor_right(m.doc_id)
				}
				else {}
			}
		}
		.special {
			match msg.string() {
				'left' {
					m.doc_controller.move_cursor_left(m.doc_id)
				}
				'down' {
					m.doc_controller.move_cursor_down(m.doc_id)
				}
				'right' {
					m.doc_controller.move_cursor_right(m.doc_id)
				}
				'up' {
					m.doc_controller.move_cursor_up(m.doc_id)
				}
				else {}
			}
		}
	}
	m.scroll_to_cursor()
	return m.clone(), tea.noop_cmd
}

fn (mut m EditorModel2) insert_mode_update(msg tea.KeyMsg) (tea.Model, fn () tea.Msg) {
	match msg.k_type {
		.runes {
			for cb in msg.string().bytes() {
				m.doc_controller.insert(m.doc_id, cb)
			}
		}
		.special {
			match msg.string() {
				'enter' {
					m.doc_controller.insert(m.doc_id, `\n`)
				}
				'ctrl+i' { // TAB
					m.doc_controller.insert(m.doc_id, `\t`)
				}
				'backspace' {
					m.doc_controller.backspace(m.doc_id)
				}
				'delete' {
					m.doc_controller.delete(m.doc_id)
				}
				'left' {
					m.doc_controller.move_cursor_left(m.doc_id)
				}
				'down' {
					m.doc_controller.move_cursor_down(m.doc_id)
				}
				'right' {
					m.doc_controller.move_cursor_right(m.doc_id)
				}
				'up' {
					m.doc_controller.move_cursor_up(m.doc_id)
				}
				else {}
			}
		}
	}
	m.scroll_to_cursor()
	return m.clone(), tea.noop_cmd
}

fn (mut m EditorModel2) scroll_to_cursor() {
	cursor_line_u, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
	cursor_line := int(cursor_line_u)
	line_count := int(m.doc_controller.line_count(m.doc_id))

	if cursor_line < m.top_line {
		m.top_line = cursor_line
	} else if cursor_line >= m.top_line + m.viewport_height {
		m.top_line = cursor_line - m.viewport_height + 1
	}

	max_top := if line_count > m.viewport_height { line_count - m.viewport_height } else { 0 }
	if m.top_line > max_top {
		m.top_line = max_top
	}
	if m.top_line < 0 {
		m.top_line = 0
	}
}

fn (m EditorModel2) view(mut ctx tea.Context) {
	m.render_cursor_and_line_highlight(mut ctx)
	line_count := int(m.doc_controller.line_count(m.doc_id))
	end := if m.top_line + m.viewport_height < line_count { m.top_line + m.viewport_height } else { line_count }
	for y in m.top_line .. end {
		line_bytes := m.doc_controller.get_line_bytes(m.doc_id, u64(y)) or { []u8{} }
		line_str := line_bytes.bytestr().replace('\t', '    ')
		ctx.draw_text(0, y - m.top_line, line_str)
	}
}

fn (m EditorModel2) render_cursor_and_line_highlight(mut ctx tea.Context) {
	cursor_line, cursor_col := m.doc_controller.cursor_line_and_x(m.doc_id)
	ctx.set_bg_color(m.theme.cursor_line_bg)
	ctx.draw_rect(0, int(cursor_line) - m.top_line, m.viewport_width, 1)
	ctx.reset_bg_color()

	line_bytes := m.doc_controller.get_line_bytes(m.doc_id, cursor_line) or { []u8{} }
	runes := line_bytes.bytestr().runes()
	tab_width := 4
	col := int(cursor_col) // logical column == rune index

	// logical column -> visual column: sum display widths of runes before the cursor
	mut visual_x := 0
	for i := 0; i < col && i < runes.len; i++ {
		visual_x += rune_display_width(runes[i], tab_width)
	}

	// width of the glyph sitting under the cursor (min 1 so the block is visible)
	cursor_width := if col < runes.len {
		w := rune_display_width(runes[col], tab_width)
		if w < 1 { 1 } else { w }
	} else {
		1
	}

	default_bg_color := ctx.get_default_bg_color() or { palette.matte_black_bg_color }
	ctx.set_bg_color(palette.fg_color(default_bg_color))
	ctx.set_color(default_bg_color)
	ctx.draw_rect(visual_x, int(cursor_line) - m.top_line, cursor_width, 1)
	ctx.reset_bg_color()
	ctx.reset_color()
}

fn (m EditorModel2) width() int {
	return m.viewport_width
}

fn (m EditorModel2) height() int {
	return m.viewport_height
}

fn (m EditorModel2) data() EditorData {
	cursor_line, cursor_x := m.doc_controller.cursor_line_and_x(m.doc_id)
	return EditorData{
		id:        m.id
		file_path: m.file_path

		cursor_row: int(cursor_line)
		cursor_col: int(cursor_x)

		chord_display: m.chord.display()
		
		width: m.viewport_width
		height: m.viewport_height
	}
}

fn (m EditorModel2) debug_data() DebugData {
	cursor_line, cursor_x := m.doc_controller.cursor_line_and_x(m.doc_id)
	return DebugData{
		name: 'active editor data'
		data: {
			'id':         '${m.id}'
			'doc_id':     '${m.doc_id}'
			'cursor_row': '${int(cursor_line)}'
			'cursor_col': '${int(cursor_x)}'
			'width':      '${m.viewport_width}'
			'height':     '${m.viewport_height}'
		}
	}
}

fn (m EditorModel2) clone() tea.Model {
	return EditorModel2{
		...m
	}
}

fn rune_display_width(r rune, tab_width int) int {
	if r == `\t` {
		return tab_width
	}
	return char_width(r)
}

fn char_width(r rune) int {
	return utf8_str_visible_length(r.str())
}


