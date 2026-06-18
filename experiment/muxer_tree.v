module main

import bobatea as tea

enum SplitDirection {
	horizontal // children sit side by side  -> divide width
	vertical   // children stack top/bottom   -> divide height
}

// Node is either a leaf (an actual pane, identified by editor_id) or an
// internal container (direction + two children) that renders nothing itself
// and just subdivides its rectangle. A leaf has editor_id >= 0 and nil
// children; an internal node has editor_id == -1 and two non-nil children.
@[heap]
struct Node {
mut:
	parent &Node = unsafe { nil }
	// leaf data:
	editor_id int = -1
	// internal data:
	direction    SplitDirection
	first_child  &Node = unsafe { nil }
	second_child &Node = unsafe { nil }
}

fn (n &Node) is_leaf() bool {
	return n.first_child == unsafe { nil }
}

// split turns the leaf carrying target_editor_id into an internal container:
// first_child keeps the original editor, second_child gets new_editor_id.
fn (mut n Node) split(target_editor_id int, new_editor_id int, direction SplitDirection) bool {
	if n.is_leaf() {
		if n.editor_id == target_editor_id {
			n.direction = direction
			n.first_child = &Node{ editor_id: n.editor_id, parent: &n }
			n.second_child = &Node{ editor_id: new_editor_id, parent: &n }
			n.editor_id = -1
			return true
		}
		return false
	}
	if n.first_child.split(target_editor_id, new_editor_id, direction) {
		return true
	}
	if n.second_child.split(target_editor_id, new_editor_id, direction) {
		return true
	}
	return false
}

struct Tree {
mut:
	root             Node
	active_editor_id int
	next_editor_id   int
}

fn (mut t Tree) plant() {
	t.root = Node{ editor_id: 0 }
	t.active_editor_id = 0
	t.next_editor_id = 1
}

fn (mut t Tree) split(direction SplitDirection) {
	new_editor_id := t.next_editor_id
	if t.root.split(t.active_editor_id, new_editor_id, direction) {
		t.next_editor_id += 1
		t.active_editor_id = new_editor_id
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

fn AppModel.new(mut t Tree) AppModel {
	return AppModel{ tree: t }
}

fn (mut m AppModel) init() fn () tea.Msg {
	m.tree.plant()
	return tea.emit_resize
}

struct SplitMsg {
	direction SplitDirection
}

fn (mut m AppModel) update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
	match msg {
		SplitMsg {
			m.tree.split(msg.direction)
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
						's' { return m.clone(), fn () tea.Msg { return SplitMsg{ direction: .horizontal } } }
						'v' { return m.clone(), fn () tea.Msg { return SplitMsg{ direction: .vertical } } }
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
	// m.draw_app_border(mut ctx)
	render_tree(mut ctx, m.width, m.height, m.tree)
	ctx.pop_offset()
}

fn render_tree(mut ctx tea.Context, width int, height int, tree Tree) {
	render_node(mut ctx, 0, 0, width, height, &tree.root, tree.active_editor_id)
}

fn render_node(mut ctx tea.Context, x int, y int, width int, height int, node &Node, active_editor_id int) {
	if node.is_leaf() {
		ctx.set_color(if node.editor_id == active_editor_id {
			active_outline_color
		} else {
			inactive_outline_color
		})
		render_box_outline(mut ctx, x, y, width, height)
		ctx.reset_color()

		ctx.draw_text(x + 1, y + 1, 'EDITOR(${node.editor_id})')
		return
	}

	// internal container: subdivide our rectangle along the split axis. The
	// second child takes the remainder so odd sizes don't drop a row/column.
	match node.direction {
		.horizontal {
			lw := width / 2
			render_node(mut ctx, x, y, lw, height, node.first_child, active_editor_id)
			render_node(mut ctx, x + lw, y, width - lw, height, node.second_child,
				active_editor_id)
		}
		.vertical {
			lh := height / 2
			render_node(mut ctx, x, y, width, lh, node.first_child, active_editor_id)
			render_node(mut ctx, x, y + lh, width, height - lh, node.second_child,
				active_editor_id)
		}
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
	right := x + width
	bottom := y + height

	// corners
	ctx.draw_text(x, y, '${box_top_left_corner.bytestr()}')
	ctx.draw_text(right, y, '${box_top_right_corner.bytestr()}')
	ctx.draw_text(x, bottom, '${box_bottom_left_corner.bytestr()}')
	ctx.draw_text(right, bottom, '${box_bottom_right_corner.bytestr()}')

	// horizontal edges (top + bottom)
	ctx.set_stroke('${box_horizontal.bytestr()}')
	ctx.draw_line(x + 1, y, right - 1, y, true)
	ctx.draw_line(x + 1, bottom, right - 1, bottom, true)

	// vertical edges (left + right)
	ctx.set_stroke('${box_vertical.bytestr()}')
	ctx.draw_line(x, y + 1, x, bottom - 1, true)
	ctx.draw_line(right, y + 1, right, bottom - 1, true)

	ctx.set_stroke(' ')
}

fn (m AppModel) clone() tea.Model {
	return AppModel{
		...m
	}
}

fn main() {
	mut tree := Tree{}
	mut app_model := AppModel.new(mut tree)
	mut app := tea.new_program(mut app_model)
	app.run() or { panic('something went wrong!: ${err}') }
}
