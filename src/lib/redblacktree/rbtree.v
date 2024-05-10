module redblacktree

import strings

type Color = bool

const black = Color(true)
const red   = Color(false)

pub type Comparator[K] = fn (x K, y K) int

@[heap]
pub struct Tree[K, V] {
mut:
	root &Node[K, V]
	size int
	cmp  Comparator[K]
}

@[heap]
pub struct Node[K, V] {
mut:
	key   K
	value V
	color Color
	left   &Node[K, V]
	right  &Node[K, V]
	parent &Node[K, V]
}

pub fn Tree.new[K, V](cmp Comparator[K]) &Tree[K, V] {
	return &Tree[K, V]{ root: unsafe { nil }, cmp: cmp }
}

pub fn (mut tree Tree[K, V]) put(key K, value V) {
	mut inserted_node := &Node[K, V](unsafe { nil })
	defer {
		tree.insert_case_1(mut inserted_node)
		tree.size += 1
	}

	if tree.root == unsafe { nil } {
		tree.root = &Node[K, V]{
			key: key, value: value, color: red, left: unsafe { nil }, right: unsafe { nil }, parent: unsafe { nil }
		}
		inserted_node = tree.root
		return
	}

	mut node := tree.root
	mut loop := true
	for loop {
		compare := tree.cmp(key, node.key)
		match true {
			compare == 0 {
				node.key = key
				node.value = value
				return
			}
			compare < 0 {
				if node.left == unsafe { nil } {
					node.left = &Node[K, V]{
						key: key, value: value, color: red, left: unsafe { nil }, right: unsafe { nil }, parent: unsafe { nil }
					}
					inserted_node = node.left
					loop = false
					continue
				}
				node = node.left
			}
			compare > 0 {
				if node.right == unsafe { nil } {
					node.right = &Node[K, V]{
						key: key, value: value, color: red, left: unsafe { nil }, right: unsafe { nil }, parent: unsafe { nil }
					}
					inserted_node = node.right
					loop = false
					continue
				}
				node = node.right
			}
			else {}
		}
	}
	inserted_node.parent = node
}

fn (tree Tree[K, V]) to_string() string {
	mut str_builder := strings.new_builder(0)
	if !tree.empty() {
		output[K, V](tree.root, "", true, mut &str_builder)
	}
	return str_builder.str()
}

fn (node &Node[K, V]) to_string() string {
	return "${node.key}"
}

fn output[K, V](node &Node[K, V], prefix string, is_tail bool, mut str_builder &strings.Builder) {
	if node.right != unsafe { nil } {
		mut new_prefix := prefix
		if is_tail { new_prefix += "|   " } else { new_prefix += "    " }
		output[K, V](node.right, new_prefix, false, mut str_builder)
	}

	str_builder.write_string(prefix)
	if is_tail { str_builder.write_string("└── ") } else { str_builder.write_string("┌── ") }
	str_builder.write_string("${node.to_string()}\n")

	if node.left != unsafe { nil } {
		mut new_prefix := prefix
		if is_tail { new_prefix += "    " } else { new_prefix += "|   " }
		output[K, V](node.left, new_prefix, true, mut str_builder)
	}
}

fn (node &Node[K, V]) grandparent() &Node[K, V] {
	if node.parent != unsafe { nil } {
		return node.parent.parent
	}
	return unsafe { nil }
}

fn (node &Node[K, V]) uncle() &Node[K, V] {
	if node.parent == unsafe { nil } || node.parent.parent == unsafe { nil } {
		return unsafe { nil }
	}
	return node.parent.sibling()
}

fn (node &Node[K, V]) sibling() &Node[K, V] {
	if node == unsafe { nil } || node.parent == unsafe { nil } {
		return unsafe { nil }
	}
	if node == node.parent.left {
		return node.parent.right
	}
	return node.parent.left
}

fn (mut tree Tree[K, V]) rotate_left(mut node &Node[K, V]) {
	mut right := node.right
	tree.replace_node(mut node, mut right)
	node.right = right.left
	if right.left != unsafe { nil } {
		right.left.parent = node
	}
	right.left = node
	node.parent = right
}

fn (mut tree Tree[K, V]) rotate_right(mut node &Node[K, V]) {
	mut left := node.left
	tree.replace_node(mut node, mut left)
	node.left = left.right
	if left.right != unsafe { nil } {
		left.right.parent = node
	}
	left.right = node
	node.parent = left
}

fn (mut tree Tree[K, V]) replace_node(mut old &Node[K, V], mut new &Node[K, V]) {
	if old.parent == unsafe { nil } {
		tree.root = new
	} else {
		if old == old.parent.left {
			old.parent.left = new
		} else {
			old.parent.right = new
		}
	}

	if new != unsafe { nil } {
		new.parent = old.parent
	}
}


fn (mut tree Tree[K, V]) insert_case_1(mut node &Node[K, V]) {
	if node.parent == unsafe { nil } {
		node.color = black
		return
	}
	tree.insert_case_2(mut node)
}

fn (mut tree Tree[K, V]) insert_case_2(mut node &Node[K, V]) {
	if node_color[K, V](node.parent) == black {
		return
	}
	tree.insert_case_3(mut node)
}

fn (mut tree Tree[K, V]) insert_case_3(mut node &Node[K, V]) {
	mut uncle := node.uncle()
	if node_color[K, V](uncle) == red {
		node.parent.color = black
		uncle.color = black
		node.grandparent().color = red
		tree.insert_case_1(mut node.grandparent())
		return
	}
	tree.insert_case_4(mut node)
}

fn (mut tree Tree[K, V]) insert_case_4(mut node &Node[K, V]) {
	grandparent := node.grandparent()
	if node == node.parent.right && node.parent == grandparent.left {
		tree.rotate_left(mut node.parent)
		node = node.left
		tree.insert_case_5(mut node)
		return
	}

	if node == node.parent.left && node.parent == grandparent.right {
		tree.rotate_right(mut node.parent)
		node = node.right
		tree.insert_case_5(mut node)
		return
	}
}

fn (mut tree Tree[K, V]) insert_case_5(mut node &Node[K, V]) {
	node.parent.color = black
	mut grandparent := node.grandparent()
	grandparent.color = red

	if node == node.parent.left && node.parent == grandparent.left {
		tree.rotate_right(mut grandparent)
		return
	}

	if node == node.parent.right && node.parent == grandparent.right {
		tree.rotate_left(mut grandparent)
		return
	}
}

fn (tree Tree[K, V]) empty() bool { return tree.size == 0 }

fn node_color[K, V](node ?&Node[K, V]) Color {
	if n := node {
		return n.color
	}
	return black
}

