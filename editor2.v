module main

import os
import bobatea as tea
import lib.documents
import lib.palette

struct EditorModel2 {
	doc_id         int
	doc_controller &documents.Controller2
	chord          Chord
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
	return m.clone(), tea.noop_cmd
}

fn (mut m EditorModel2) view(mut ctx tea.Context) {
	cursor_line, cursor_x := m.doc_controller.cursor_line_and_x(m.doc_id)
	line_count := int(m.doc_controller.line_count(m.doc_id))
	mut cursor_visual_x := 0
	for y in 0..line_count {
		line_bytes := m.doc_controller.get_line_bytes(m.doc_id, u64(y)) or { []u8{} }
		line_str := line_bytes.bytestr().replace('\t', '    ')
		if y == cursor_line {
			end := if int(cursor_x) > line_bytes.len { line_bytes.len } else { int(cursor_x) }
			before_cursor := line_bytes[..end].bytestr()
			for r in before_cursor.runes() {
				if r == `\t` {
					cursor_visual_x += 4
				} else {
					cursor_visual_x += 1
				}
			}
		}
		ctx.draw_text(0, y, line_str)
	}
	ctx.set_bg_color(palette.petal_red_color)
	ctx.draw_text(cursor_visual_x, int(cursor_line), '|')
	ctx.reset_bg_color()
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


