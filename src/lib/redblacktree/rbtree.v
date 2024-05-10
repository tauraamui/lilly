module redblacktree

type Color = bool

const black = Color(true)
const red   = Color(false)

pub type Comparator[K] = fn (x K, y K) int

@[heap]
pub struct Tree[K, V] {
mut:
	root ?Node[K, V]
	size int
	cmp  Comparator[K]
}

@[heap]
pub struct Node[K, V] {
mut:
	key   K
	value V
	color Color
	left   ?&Node[K, V]
	right  ?&Node[K, V]
	parent ?&Node[K, V]
}

pub fn Tree.new[K, V](cmp Comparator[K]) &Tree[K, V] {
	return &Tree[K, V]{ cmp: cmp }
}

pub fn (mut tree Tree[K, V]) put(key K, value V) {
	defer { tree.size += 1 }

	if mut root := tree.root {
		tree.place_node_into_existing(key, value, mut &root)
		return
	}
	tree.root = Node[K, V]{ key: key, value: value, color: red }
}

fn (mut tree Tree[K, V]) place_node_into_existing(key K, value V, mut existing_node &Node[K, V]) {
	mut loop := true
	mut focused_node := &existing_node
	mut inserted_node := Node[K, V]{ key: key, value: value, color: red }
	for loop {
		compare := tree.cmp(key, focused_node.key)
		match true {
			compare == 0 {
				focused_node.key = key
				focused_node.value = value
				return
			}
			compare < 0 {
				if mut left := focused_node.left {
					focused_node = left
					continue
				}
				focused_node.left = &Node[K, V]{ key: key, value: value, color: red, parent: &focused_node }
				if left := focused_node.left { inserted_node = left }
				loop = false
				continue
			}
			compare > 0 {
				if mut right := focused_node.right {
					focused_node = right
					continue
				}
				focused_node.right = &Node[K, V]{ key: key, value: value, color: red, parent: &focused_node }
				if right := focused_node.right { inserted_node = right }
				loop = false
				continue
			}
			else {}
		}
	}
	tree.insert_case_1(mut inserted_node)
}

fn (node &Node[K, V]) grandparent() ?&Node[K, V] {
	if parent := node.parent {
		if grandparent := parent.parent { return grandparent }
	}
	return none
}

fn (node &Node[K, V]) uncle() ?&Node[K, V] {
	parent := node.parent or { return none }
	return parent.sibling()
}

fn (node &Node[K, V]) sibling() ?&Node[K, V] {
	if parent := node.parent {
		if node == parent.left? { return parent.right }
		return parent.left
	}
	return none
}

fn (mut tree Tree[K, V]) rotate_left(mut node &Node[K, V]) {
	if mut right := node.right {
		tree.replace_node(node, mut right)
		if mut right_left := right.left {
			node.right = right_left
			if right_left != unsafe { nil } {
				right_left.parent = node
			}
			right_left.left = node
			node.parent = right
		}
	}
}

fn (mut tree Tree[K, V]) rotate_right(mut node &Node[K, V]) {
	if mut left := node.left {
		tree.replace_node(node, mut left)
		if mut left_right := left.right {
			if left_right != unsafe { nil } {
				left_right.parent = node
			}
			left_right.right = node
			node.parent = left
		}
	}
}

fn (mut tree Tree[K, V]) replace_node(old &Node[K, V], mut new &Node[K, V]) {
	if old_parent := old.parent {
		if old_parent == unsafe { nil } { tree.root = new; return }
		if mut old_parent_left := old_parent.left {
			if old == old_parent_left {
				old_parent_left = new
				return
			}
		}
		if mut old_parent_right := old_parent.right {
			old_parent_right = new
		}
		if new != unsafe { nil } {
			new.parent = old_parent
		}
	}
}


fn (mut tree Tree[K, V]) insert_case_1(mut node &Node[K, V]) {
	if parent := node.parent {
		tree.insert_case_2(mut node)
		return
	}
	node.color = black
}

fn (mut tree Tree[K, V]) insert_case_2(mut node &Node[K, V]) {
	if parent := node.parent {
		if node_color[K, V](parent) == black { return }
		tree.insert_case_3(mut node)
	}
}

fn (mut tree Tree[K, V]) insert_case_3(mut node &Node[K, V]) {
	if mut uncle := node.uncle() {
		if node_color[K, V](uncle) == red {
			if mut parent := node.parent {
				parent.color = black
				uncle.color = black
				if mut grandparent := node.grandparent() {
					grandparent.color = red
					tree.insert_case_1(mut grandparent)
				}
			}
			return
		}
		tree.insert_case_4(mut node)
	}
}

fn (mut tree Tree[K, V]) insert_case_4(mut node &Node[K, V]) {
	if grandparent := node.grandparent() {
		if mut parent := node.parent {
			if node == parent.right or { unsafe { nil } } && parent == grandparent.left or { unsafe { nil } } {
				tree.rotate_left(mut parent)
				if node_left := node.left { node = node_left }
			} else if node == parent.left or { unsafe { nil } } && parent == grandparent.right or { unsafe { nil } } {
				tree.rotate_right(mut parent)
				if node_right := node.right { node = node_right }
			}
		}
	}
	tree.insert_case_5(mut node)
}

fn (mut tree Tree[K, V]) insert_case_5(mut node &Node[K, V]) {
	if mut parent := node.parent {
		parent.color = black
		if mut grandparent := node.grandparent() {
			grandparent.color = red
			if node == parent.left or { unsafe { nil } } && parent == grandparent.left or { unsafe { nil } } {
				tree.rotate_right(mut grandparent)
			} else if node == parent.right or { unsafe { nil } } && parent == grandparent.right or { unsafe { nil } } {
				tree.rotate_left(mut grandparent)
			}
		}
	}
}

fn node_color[K, V](node ?&Node[K, V]) Color {
	if n := node {
		return n.color
	}
	return black
}

