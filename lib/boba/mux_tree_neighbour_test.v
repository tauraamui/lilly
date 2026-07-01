module boba

// layout under test (80x24):
//   left half = 1, right half split vertically into 2 (top) and 3 (bottom)
// +--------+--------+
// |        |   2    |
// |   1    +--------+
// |        |   3    |
// +--------+--------+
fn scratch_tree() Tree[int] {
	mut t := Tree[int]{}
	t.plant(1)
	t.split(1, 2, .horizontal)
	t.split(2, 3, .vertical)
	return t
}

fn test_neighbour_horizontal_moves() {
	t := scratch_tree()
	// from the tall left leaf, moving right lands on the top-right leaf (it
	// hugs the divider at the top where the walk first meets it).
	assert t.neighbour(1, .right, 80, 24)? == 2
	// from either right leaf, moving left returns to the single left leaf.
	assert t.neighbour(2, .left, 80, 24)? == 1
	assert t.neighbour(3, .left, 80, 24)? == 1
}

fn test_neighbour_vertical_moves() {
	t := scratch_tree()
	assert t.neighbour(2, .down, 80, 24)? == 3
	assert t.neighbour(3, .up, 80, 24)? == 2
}

fn test_neighbour_none_at_edges() {
	t := scratch_tree()
	// nothing to the left of the left leaf, nor above/below it (it spans full height).
	assert t.neighbour(1, .left, 80, 24) == none
	assert t.neighbour(1, .up, 80, 24) == none
	assert t.neighbour(1, .down, 80, 24) == none
	// top-right leaf has nothing above it, bottom-right nothing below.
	assert t.neighbour(2, .up, 80, 24) == none
	assert t.neighbour(3, .down, 80, 24) == none
}

fn test_neighbour_unknown_id() {
	t := scratch_tree()
	assert t.neighbour(99, .left, 80, 24) == none
}

fn test_neighbour_single_leaf() {
	mut t := Tree[int]{}
	t.plant(1)
	assert t.neighbour(1, .right, 80, 24) == none
}
