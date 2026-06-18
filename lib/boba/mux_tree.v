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

pub fn (t Tree) view(editor_id int) {
}
