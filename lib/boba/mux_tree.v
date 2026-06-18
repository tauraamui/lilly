module boba

enum SplitDirection {
	horizontal // children positioned side by side -> fraction of width
	vertical   // children stacked top to bottom   -> fraction of height
}

@[heap]
struct Node {
mut:
	parent       &Node = unsafe { nil }
	// leaf data
	editor_id    int = -1
	// internal data:
	direction    SplitDirection
	first_child  &Node = unsafe { nil }
	second_child &Node = unsafe { nil }
}

fn (n &Node) is_leaf() bool {
	return n.first_child == unsafe { nil }
}

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

pub struct Tree {
mut:
	root             Node
	active_editor_id int
	next_editor_id   int
}

pub fn (mut t Tree) plant() {
	t.root = Node{ editor_id: 0 }
	t.active_editor_id = 0
	t.next_editor_id = 1
}

pub fn (mut t Tree) split(direction SplitDirection) {
	new_editor_id := t.next_editor_id
	if t.root.split(t.active_editor_id, new_editor_id, direction) {
		t.next_editor_id += 1
		t.active_editor_id = new_editor_id
	}
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
pub fn (t Tree) layouts(max_width int, max_height int) map[int]Layout {
	mut out := map[int]Layout{}
	t.root.layout(0, 0, max_width, max_height, mut out)
	return out
}

fn (n &Node) layout(x int, y int, width int, height int, mut out map[int]Layout) {
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
