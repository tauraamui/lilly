module main

import bobatea as tea

@[heap]
struct Node {
mut:
	id int
	parent        &Node = unsafe { nil }
	first_child   &Node = unsafe { nil }
	second_child  &Node = unsafe { nil }
}

fn (mut n Node) split(id int, first_id int, second_id int) bool {
	if n.id == id {
		n.first_child = &Node{ id: first_id, parent: &n }
		n.second_child = &Node{ id: second_id, parent: &n }
		return true
	}
	if n.first_child != unsafe { nil } && n.first_child.split(id, first_id, second_id) {
		return true
	}
	if n.second_child != unsafe { nil } && n.second_child.split(id, first_id, second_id) {
		return true
	}
	return false
}

struct Tree {
mut:
	root        Node
	active_node int
	next_id     int
}

fn (mut t Tree) plant() {
	t.root = Node{ id: 0 }
	t.active_node = 0
	t.next_id = 1
}

fn (mut t Tree) split() {
	first_id := t.next_id
	second_id := t.next_id + 1
	if t.root.split(t.active_node, first_id, second_id) {
		t.next_id += 2
		t.active_node = second_id
	}
}

@[noinit]
struct AppModel {
mut:
	x         int
	y         int
	width     int
	height    int
	tree      Tree
}

fn AppModel.new() AppModel {
	return AppModel{}
}

fn (mut m AppModel) init() fn () tea.Msg {
	m.tree.plant()
	return tea.emit_resize
}

struct SplitMsg {}

fn (mut m AppModel) update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
	match msg {
		SplitMsg {
			m.tree.split()
			return m.clone(), tea.noop_cmd
		}
		tea.ResizedMsg {
			m.width = msg.window_width - 1
			m.height = msg.window_height - 1
		}
		tea.KeyMsg {
			match msg.k_type {
				.special {
					if msg.string() == 'escape' { return m.clone(), tea.quit }
				}
				.runes {
					match msg.string() {
						'q' { return m.clone(), tea.quit }
						's' { return m.clone(), fn () tea.Msg { return SplitMsg{} } }
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
	m.draw_app_border(mut ctx)
	render_tree(mut ctx, m.width, m.height, m.tree)
	ctx.pop_offset()
}

fn render_tree(mut ctx tea.Context, width int, height int, tree Tree) {
	render_node(mut ctx, 0, 0, width, height, tree.root, tree.active_node)
	// remaining_width /= 2
	// ctx.push_offset(tea.Offset{ x: remaining_width, y: 0 })
	// render_node(mut ctx, remaining_width, height, tree.root.first_child, inactive_outline_color)
}

fn render_node(mut ctx tea.Context, x int, y int, width int, height int, node Node, active_node int) {
	ctx.set_color(if node.id == active_node { active_outline_color } else { inactive_outline_color })
	render_box_outline(mut ctx, x, y, width, height)
	ctx.reset_color()
	
	node_label := 'NODE(${node.id})'
	ctx.draw_text(x + 1, y + 1, node_label)
	
	if node.first_child != unsafe { nil } {
		render_node(mut ctx, x, y, width / 2, height, node.first_child, active_node)
	}
	
	if node.second_child != unsafe { nil } {
		render_node(mut ctx, x + (width / 2), y, width / 2, height, node.second_child, active_node)
	}
}

const box_top_left_corner     = [u8(0xe2), 0x94, 0x8c]
const box_top_right_corner    = [u8(0xe2), 0x94, 0x90]
const box_bottom_right_corner = [u8(0xe2), 0x94, 0x98]
const box_bottom_left_corner  = [u8(0xe2), 0x94, 0x94]
const box_horizontal          = [u8(0xe2), 0x94, 0x80]
const box_vertical            = [u8(0xe2), 0x94, 0x82]

const app_outline_color = tea.Color.ansi(45)
const active_outline_color = tea.Color.ansi(27)
const inactive_outline_color = tea.Color.ansi(198)

fn (m AppModel) draw_app_border(mut ctx tea.Context) {
	ctx.set_color(app_outline_color)
	render_box_outline(mut ctx, 0, 0, m.width, m.height)
	ctx.reset_color()
}

fn render_box_outline(mut ctx tea.Context, x int, y int, width int, height int) {
	ctx.draw_text(x, y, '${box_top_left_corner.bytestr()}')
	ctx.set_stroke('${box_horizontal.bytestr()}')
	ctx.draw_line(x + 1, y, width, y, true)
	ctx.set_stroke('${box_vertical.bytestr()}')
	ctx.draw_line(x, y + 1, x, height, true)
	ctx.draw_text(x + width, y, '${box_top_right_corner.bytestr()}')
	ctx.set_stroke('${box_vertical.bytestr()}')
	ctx.draw_line(x + width, y + 1, x + width, height, true)
	ctx.draw_text(x + width, height, '${box_bottom_right_corner.bytestr()}')
	ctx.set_stroke('${box_horizontal.bytestr()}')
	ctx.draw_line(x, height, x + width - 1, height, true)
	ctx.draw_text(x, height, '${box_bottom_left_corner.bytestr()}')
	ctx.set_stroke(' ')
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
