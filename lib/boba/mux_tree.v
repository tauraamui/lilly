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
