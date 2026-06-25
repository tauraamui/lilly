module boba

pub enum SplitDirection {
	horizontal // children positioned side by side -> fraction of width
	vertical   // children stacked top to bottom   -> fraction of height
}

@[heap]
struct Node[T] {
mut:
	parent       &Node[T] = unsafe { nil }
	// leaf data: only meaningful while the node is a leaf (is_leaf() == true)
	editor_id    T
	// internal data:
	direction    SplitDirection
	first_child  &Node[T] = unsafe { nil }
	second_child &Node[T] = unsafe { nil }
}

fn (n &Node[T]) is_leaf() bool {
	return n.first_child == unsafe { nil }
}

fn (mut n Node[T]) split(target_editor_id T, new_editor_id T, direction SplitDirection) bool {
	if n.is_leaf() {
		if n.editor_id == target_editor_id {
			n.direction = direction
			n.first_child = &Node[T]{ editor_id: n.editor_id, parent: &n }
			n.second_child = &Node[T]{ editor_id: new_editor_id, parent: &n }
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

pub struct Tree[T] {
mut:
	root Node[T]
}

// plant seeds the tree with a single leaf holding the given, externally
// managed editor_id. Editor id allocation and active tracking live with the
// caller; the tree only stores the ids it is told to. The id type T is chosen
// by the caller (e.g. int, or nanoid.ID), the tree only compares ids for
// equality and uses them as map keys.
pub fn (mut t Tree[T]) plant(editor_id T) {
	t.root = Node[T]{ editor_id: editor_id }
}

// split finds the leaf holding target_editor_id and splits it along direction,
// placing new_editor_id in the freshly created second child. Both ids are
// supplied by the caller. Returns true when the target leaf was found.
pub fn (mut t Tree[T]) split(target_editor_id T, new_editor_id T, direction SplitDirection) bool {
	return t.root.split(target_editor_id, new_editor_id, direction)
}

pub struct Layout {
pub:
	x      int
	y      int
	width  int
	height int
}

// layouts walks the tree once, subdividing the screen rectangle, and returns
// the rectangle each leaf editor occupies keyed by its editor_id. Internal
// nodes render nothing themselves; they just split their rectangle along the
// node's direction, with the second child taking the remainder so odd sizes
// don't drop a row/column.
pub fn (t Tree[T]) layouts(max_width int, max_height int) map[T]Layout {
	mut out := map[T]Layout{}
	t.root.layout(0, 0, max_width, max_height, mut out)
	return out
}

fn (n &Node[T]) layout(x int, y int, width int, height int, mut out map[T]Layout) {
	if n.is_leaf() {
		out[n.editor_id] = Layout{ x: x, y: y, width: width, height: height }
		return
	}
	match n.direction {
		.horizontal {
			lw := width / 2
			n.first_child.layout(x, y, lw, height, mut out)
			n.second_child.layout(x + lw, y, width - lw, height, mut out)
		}
		.vertical {
			lh := height / 2
			n.first_child.layout(x, y, width, lh, mut out)
			n.second_child.layout(x, y + lh, width, height - lh, mut out)
		}
	}
}

// edge_* mark, during a divider walk, which sides of the current rectangle are
// themselves dividers (an ancestor split) rather than the outer screen
// boundary. A divider line that ends on such a side meets another line there,
// so the cell is a junction (tee) instead of a plain line end.
const edge_top = u8(1)
const edge_bottom = u8(2)
const edge_left = u8(4)
const edge_right = u8(8)

// DividerVisitor receives one divider cell: its position and which of the four
// directions a divider line continues toward. The caller maps those to a box
// glyph and colour; the tree stays render-agnostic.
pub type DividerVisitor = fn (x int, y int, up bool, down bool, left bool, right bool)

// each_divider walks the tree with the same subdivision arithmetic as
// layouts() and reports every divider cell, so positions always line up with
// the leaf boundaries. Junctions are resolved from edge flags alone — no
// second pass or per-cell grid — which is enough because splits only ever
// subdivide a leaf into a fresh second_child, so a divider only ever meets an
// ancestor edge, never crosses a sibling mid-span.
pub fn (t Tree[T]) each_divider(max_width int, max_height int, visit DividerVisitor) {
	t.root.each_divider(0, 0, max_width, max_height, 0, visit)
}

fn (n &Node[T]) each_divider(x int, y int, width int, height int, edges u8, visit DividerVisitor) {
	if n.is_leaf() {
		return
	}
	match n.direction {
		.horizontal {
			lw := width / 2
			dx := x + lw
			top_join := edges & edge_top != 0
			bottom_join := edges & edge_bottom != 0
			for ry in y .. y + height {
				join := (ry == y && top_join) || (ry == y + height - 1 && bottom_join)
				visit(dx, ry, ry > y, ry < y + height - 1, join, join)
			}
			n.first_child.each_divider(x, y, lw, height, edges | edge_right, visit)
			n.second_child.each_divider(dx, y, width - lw, height, edges | edge_left, visit)
		}
		.vertical {
			lh := height / 2
			dy := y + lh
			left_join := edges & edge_left != 0
			right_join := edges & edge_right != 0
			for cx in x .. x + width {
				join := (cx == x && left_join) || (cx == x + width - 1 && right_join)
				visit(cx, dy, join, join, cx > x, cx < x + width - 1)
			}
			n.first_child.each_divider(x, y, width, lh, edges | edge_bottom, visit)
			n.second_child.each_divider(x, dy, width, height - lh, edges | edge_top, visit)
		}
	}
}
