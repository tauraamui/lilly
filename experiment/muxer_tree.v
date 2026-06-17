module main

import bobatea as tea

struct Node {
	id int
}

@[noinit]
struct AppModel {
mut:
	x         int
	y         int
	width     int
	height    int
	root_node Node
}

fn AppModel.new() AppModel {
	return AppModel{
		root_node: Node{ id: 1 }
	}
}

fn (mut m AppModel) init() fn () tea.Msg {
	return tea.emit_resize
}

const padding = 4

fn (mut m AppModel) update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
	match msg {
		tea.ResizedMsg {
			m.x = padding / 2
			m.y = padding / 2
			m.width = msg.window_width - padding
			m.height = msg.window_height - padding
		}
		tea.KeyMsg {
			match msg.k_type {
				.special {
					if msg.string() == 'escape' { return m.clone(), tea.quit }
				}
				.runes {
					match msg.string() {
						'q' { return m.clone(), tea.quit }
						else {}
					}
				}
			}
		}
		else {}
	}
	return m.clone(), tea.noop_cmd
}

fn (m AppModel) view(mut ctx tea.Context) {
	// split_tree_msg := 'split tree experiment render test'
	// ctx.draw_text((ctx.window_width() / 2) - (tea.visible_len(split_tree_msg) / 2), ctx.window_height() / 2, split_tree_msg)
	m.draw_app_border(mut ctx)
	render_node(mut ctx, m.root_node)
}

const box_top_left_corner     = [u8(0xe2), 0x94, 0x8c]
const box_top_right_corner    = [u8(0xe2), 0x94, 0x90]
const box_bottom_right_corner = [u8(0xe2), 0x94, 0x98]
const box_bottom_left_corner  = [u8(0xe2), 0x94, 0x94]
const box_horizontal          = [u8(0xe2), 0x94, 0x80]
const box_vertical            = [u8(0xe2), 0x94, 0x82]

fn (m AppModel) draw_app_border(mut ctx tea.Context) {
	ctx.draw_text(m.x, m.y, '${box_top_left_corner.bytestr()}')
	ctx.set_stroke('${box_horizontal.bytestr()}')
	ctx.draw_line(m.x + 1, m.y, m.width, m.y, false)
	ctx.set_stroke('${box_vertical.bytestr()}')
	ctx.draw_line(m.x, m.y + 1, m.x, m.height, false)
	ctx.draw_text(m.x + m.width - 1, m.y, '${box_top_right_corner.bytestr()}')
	ctx.set_stroke('${box_vertical.bytestr()}')
	ctx.draw_line(m.x + m.width - 1, m.y + 1, m.x + m.width - 1, m.height, false)
	ctx.draw_text(m.x + m.width - 1, m.height + 1, '${box_bottom_right_corner.bytestr()}')
	ctx.set_stroke('${box_horizontal.bytestr()}')
	ctx.draw_line(m.x + 1, m.height + 1, m.x + m.width - 2, m.height + 1, false)
	ctx.draw_text(m.x, m.height + 1, '${box_bottom_left_corner.bytestr()}')
}

fn render_node(mut ctx tea.Context, node Node) {
}

fn (m AppModel) clone() tea.Model {
	return AppModel{
		...m
	}
}

fn main() {
	mut app_model := AppModel.new()
	mut app := tea.new_program(mut app_model)
	app.run() or { panic('something went wrong!: ${err}') }
}
