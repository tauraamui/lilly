module main

import os
import bobatea as tea
import lib.documents
import lib.palette

struct EditorModel2 {
	doc_id int
	doc_controller &documents.Controller2
}

fn EditorModel2.new(doc_id int, doc_controller &documents.Controller2) EditorModel2 {
	return EditorModel2{
		doc_id: doc_id
		doc_controller: doc_controller
	}
}

fn (mut m EditorModel2) init() fn () tea.Msg {
	return tea.noop_cmd
}

fn (mut m EditorModel2) update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
	return m.normal_mode_update(msg)
}

fn (mut m EditorModel2) normal_mode_update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
	match msg {
		tea.KeyMsg {
			match msg.k_type {
				.runes {
					for cb in msg.string().bytes() {
						m.doc_controller.insert(m.doc_id, cb)
					}
				}
				.special {
					match msg.string() {
						'escape' {
							return m.clone(), tea.quit
						}
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
		}
		else {}
	}
	return m.clone(), tea.noop_cmd
}

fn (mut m EditorModel2) view(mut ctx tea.Context) {
	cursor_line, cursor_x := m.doc_controller.cursor_line_and_x(m.doc_id)
	line_count := int(m.doc_controller.line_count(m.doc_id))
	for y in 0..line_count {
		line_bytes := m.doc_controller.get_line_bytes(m.doc_id, u64(y)) or { []u8{} }
		ctx.draw_text(0, y, line_bytes.bytestr().replace('\t', '    '))
	}

	cursor_line_bytes := m.doc_controller.get_line_bytes(m.doc_id, cursor_line) or { []u8{} }
	mut visual_x := 0
	limit := if int(cursor_x) < cursor_line_bytes.len { int(cursor_x) } else { cursor_line_bytes.len }
	for i in 0..limit {
		if cursor_line_bytes[i] == `\t` {
			visual_x += 4
		} else {
			visual_x += 1
		}
	}

	offset := ctx.compact_offsets()
	default_bg_color := ctx.get_default_bg_color() or { palette.matte_black_bg_color }
	ctx.set_bg_color(palette.fg_color(default_bg_color))
	ctx.set_color(default_bg_color)
	ctx.draw_text(offset.x + visual_x, offset.y + int(cursor_line), '|')
	ctx.reset_bg_color()
	ctx.reset_color()
}

fn (m EditorModel2) width() int {
	return 300
}

fn (m EditorModel2) height() int {
	return 500
}

fn (m EditorModel2) debug_data() DebugData {
	return DebugData{
		name: 'active editor data'
		data: {
			'id':         '${m.doc_id}'
			// 'file path':  m.file_path
			// 'cursor_row': '${m.cursor_pos.y}'
			// 'cursor_col': '${m.cursor_pos.x}'
		}
	}
}

fn (m EditorModel2) clone() tea.Model {
	return EditorModel2{
		...m
	}
}


