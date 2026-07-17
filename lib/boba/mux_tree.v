module boba

pub enum SplitDirection {
	horizontal // children positioned side by side -> fraction of width
	vertical   // children stacked top to bottom   -> fraction of height
}

// Direction is the axis-aligned direction of a focus move between leaves.
pub enum Direction {
	left
	right
	up
	down
}

@[heap]
struct Node[T] {
mut:
	parent &Node[T] = unsafe { nil }
	// leaf data: only meaningful while the node is a leaf (is_leaf() == true)
	editor_id T
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
			n.first_child = &Node[T]{
				editor_id: n.editor_id
				parent:    &n
			}
			n.second_child = &Node[T]{
				editor_id: new_editor_id
				parent:    &n
			}
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
	t.root = Node[T]{
		editor_id: editor_id
	}
}

// split finds the leaf holding target_editor_id and splits it along direction,
// placing new_editor_id in the freshly created second child. Both ids are
// supplied by the caller. Returns true when the target leaf was found.
pub fn (mut t Tree[T]) split(target_editor_id T, new_editor_id T, direction SplitDirection) bool {
	return t.root.split(target_editor_id, new_editor_id, direction)
}

// remove finds the leaf holding editor_id and removes it, collapsing its parent
// so the sibling subtree takes the parent's place — the inverse of split().
// Returns the id of the leaf that should take focus in the closed leaf's place:
// the leaf within the surviving sibling subtree that sat directly against the
// removed leaf (its nearest neighbour across the shared divider). Returns none
// when editor_id was not found, or when it was the only remaining leaf (the root
// has no parent to collapse into): the tree always holds at least one leaf, and
// re-seeding is the caller's job via plant().
pub fn (mut t Tree[T]) remove(editor_id T) ?T {
	return t.root.remove(editor_id)
}

fn (mut n Node[T]) remove(editor_id T) ?T {
	if n.is_leaf() {
		return none
	}
	// when one of our own children is the target leaf, this node collapses into
	// the surviving sibling; the nearest neighbour to focus is the sibling leaf
	// hugging the divider they shared. otherwise keep descending.
	if n.first_child.is_leaf() && n.first_child.editor_id == editor_id {
		focus := n.second_child.leading_leaf()
		n.absorb(n.second_child)
		return focus
	}
	if n.second_child.is_leaf() && n.second_child.editor_id == editor_id {
		focus := n.first_child.trailing_leaf()
		n.absorb(n.first_child)
		return focus
	}
	if id := n.first_child.remove(editor_id) {
		return id
	}
	return n.second_child.remove(editor_id)
}

// leading_leaf returns the editor id of the top/left-most leaf of the subtree —
// reached by always descending into the first child.
fn (n &Node[T]) leading_leaf() T {
	if n.is_leaf() {
		return n.editor_id
	}
	return n.first_child.leading_leaf()
}

// trailing_leaf returns the editor id of the bottom/right-most leaf of the
// subtree — reached by always descending into the second child.
fn (n &Node[T]) trailing_leaf() T {
	if n.is_leaf() {
		return n.editor_id
	}
	return n.second_child.trailing_leaf()
}

// absorb overwrites n in place with the contents of survivor (n's remaining
// child after its sibling was removed), keeping n's own address and parent link
// intact so pointers held elsewhere in the tree stay valid. When survivor is an
// internal node its children are reparented onto n; when it is a leaf n simply
// becomes that leaf.
fn (mut n Node[T]) absorb(survivor &Node[T]) {
	n.editor_id = survivor.editor_id
	n.direction = survivor.direction
	n.first_child = survivor.first_child
	n.second_child = survivor.second_child
	if !n.is_leaf() {
		n.first_child.parent = &n
		n.second_child.parent = &n
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
pub fn (t Tree[T]) layouts(max_width int, max_height int) map[T]Layout {
	mut out := map[T]Layout{}
	t.root.layout(0, 0, max_width, max_height, mut out)
	return out
}

fn (n &Node[T]) layout(x int, y int, width int, height int, mut out map[T]Layout) {
	if n.is_leaf() {
		out[n.editor_id] = Layout{
			x:      x
			y:      y
			width:  width
			height: height
		}
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

// neighbour returns the editor id of the leaf sitting directly against
// editor_id in the given direction — the leaf focus should move to. It decides
// adjacency geometrically from the very rectangles layouts() produces, so it
// always agrees with what the user sees: among the leaves lying on the
// requested side and overlapping editor_id along the perpendicular axis, the
// closest wins, breaking ties by the largest overlap. Returns none when
// editor_id is not a leaf in the tree, or when there is no leaf on that side
// (editor_id already hugs that edge of the screen). Pass the same
// max_width/max_height used to render so the rectangles line up.
pub fn (t Tree[T]) neighbour(editor_id T, direction Direction, max_width int, max_height int) ?T {
	rects := t.layouts(max_width, max_height)
	cur := rects[editor_id] or { return none }

	mut best := editor_id
	mut found := false
	mut best_distance := 0
	mut best_overlap := 0
	for id, rect in rects {
		if id == editor_id {
			continue
		}
		distance, overlap := directional_gap(cur, rect, direction)
		// distance < 0 means rect intrudes into cur's own span rather than
		// sitting on the requested side; overlap <= 0 means they only touch at
		// a corner (or not at all), so no shared border to cross.
		if distance < 0 || overlap <= 0 {
			continue
		}
		if !found || distance < best_distance
			|| (distance == best_distance && overlap > best_overlap) {
			best = id
			found = true
			best_distance = distance
			best_overlap = overlap
		}
	}
	if !found {
		return none
	}
	return best
}

// directional_gap measures, for a move from cur toward c in direction, the gap
// between them along the movement axis (negative when c overlaps cur's span on
// that axis) and how much they overlap along the perpendicular axis.
fn directional_gap(cur Layout, c Layout, direction Direction) (int, int) {
	match direction {
		.left {
			return cur.x - (c.x + c.width), span_overlap(cur.y, cur.y + cur.height, c.y, c.y +
				c.height)
		}
		.right {
			return c.x - (cur.x + cur.width), span_overlap(cur.y, cur.y + cur.height, c.y, c.y +
				c.height)
		}
		.up {
			return cur.y - (c.y + c.height), span_overlap(cur.x, cur.x + cur.width, c.x, c.x +
				c.width)
		}
		.down {
			return c.y - (cur.y + cur.height), span_overlap(cur.x, cur.x + cur.width, c.x, c.x +
				c.width)
		}
	}
}

// span_overlap returns the length of the overlap between the ranges [a_lo, a_hi)
// and [b_lo, b_hi); zero or negative when they do not overlap.
fn span_overlap(a_lo int, a_hi int, b_lo int, b_hi int) int {
	lo := if a_lo > b_lo { a_lo } else { b_lo }
	hi := if a_hi < b_hi { a_hi } else { b_hi }
	return hi - lo
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
