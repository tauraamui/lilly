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
	if tree.root == unsafe { nil } {
		tree.root = &Node[K, V]{ key: key, value: value, color: red, left: unsafe { nil }, right: unsafe { nil }, parent: unsafe { nil } }
		inserted_node = tree.root
	} else {
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
						node.left = &Node[K, V]{ key: key, value: value, color: red, left: unsafe { nil }, right: unsafe { nil }, parent: unsafe { nil } }
						inserted_node = node.left
						loop = false
					} else {
						node = node.left
					}
				}
				compare > 0 {
					if node.right == unsafe { nil } {
						node.right = &Node[K, V]{ key: key, value: value, color: red, left: unsafe { nil }, right: unsafe { nil }, parent: unsafe { nil } }
						inserted_node = node.right
						loop = false
					} else {
						node = node.right
					}
				}
				else { }
			}
		}
		inserted_node.parent = node
	}
	tree.insert_case_1(mut inserted_node)
	tree.size += 1
}

fn (tree Tree[K, V]) get(key K) ?V {
	if node := tree.lookup(key) { return node.value }
	return none
}

fn (tree Tree[K, V]) get_node(key K) ?&Node[K, V] {
	return tree.lookup(key)
}

fn (mut tree Tree[K, V]) remove(key K) {
	mut child := &Node[K, V](unsafe { nil })
	mut node := tree.lookup(key) or { unsafe { nil } }
	if node == unsafe { nil } { return }

	if node.left != unsafe { nil } && node.right != unsafe { nil } {
		pred := node.left.maximum_node()
		node.key = pred.key
		node.value = pred.value
		node = pred
	}

	if node.left == unsafe { nil } || node.right == unsafe { nil } {
		if node.right == unsafe { nil } {
			child = node.left
		} else {
			child = node.right
		}
		if node.color == black {
			node.color = node_color[K, V](child)
			tree.delete_case_1(mut node)
		}
		tree.replace_node(mut node, mut child)
		if node.parent == unsafe { nil } && child != unsafe { nil } {
			child.color = black
		}
	}
	tree.size -= 1
}

pub fn (tree Tree[K, V]) empty() bool {
	return tree.size == 0
}

pub fn (tree Tree[K, V]) size() int {
	return tree.size
}

pub fn (node &Node[K, V]) size() int {
	if node == unsafe { nil } {
		return 0
	}
	mut size := 1
	if node.left != unsafe { nil } {
		size += node.left.size()
	}

	if node.right != unsafe { nil } {
		size += node.right.size()
	}

	return size
}

fn (tree Tree[K, V]) keys() []K {
	mut keys := []K{ len: tree.size }
	mut it := tree.iterator()

	for i, node in it {
		keys[i] = node.key
	}
	return keys
}

fn (tree Tree[K, V]) values() []V {
	mut values := []V{ len: tree.size }
	mut it := tree.iterator()

	for i, node in it {
		values[i] = node.value
	}
	return values
}

fn (mut tree Tree[K, V]) left() &Node[K, V] {
	mut parent := &Node[K, V](unsafe { nil })
	mut current := tree.root
	for current != unsafe { nil } {
		parent = current
		current = current.left
	}
	return parent
}

fn (mut tree Tree[K, V]) right() &Node[K, V] {
	mut parent := &Node[K, V](unsafe { nil })
	mut current := tree.root
	for current != unsafe { nil } {
		parent = current
		current = current.right
	}
	return parent
}

fn (mut tree Tree[K, V]) floor(key K) ?&Node[K, V] {
	mut found := false
	mut node := tree.root
	mut floor := &Node[K, V](unsafe { nil })
	for node != unsafe { nil } {
		compare := tree.cmp(key, node.key)
		match true {
			compare == 0 {
				return node
			}
			compare < 0 {
				node = node.left
			}
			compare > 0 {
				floor = node
				found = true
				node = node.right
			}
			else { }
		}
	}
	if found { return floor }
	return none
}

fn (mut tree Tree[K, V]) ceiling(key K) ?&Node[K, V] {
	mut found := false
	mut node := tree.root
	mut ceiling := &Node[K, V](unsafe { nil })
	for node != unsafe { nil } {
		compare := tree.cmp(key, node.key)
		match true {
			compare == 0 {
				return node
			}
			compare < 0 {
				ceiling = node
				found = true
				node = node.left
			}
			compare > 0 {
				node = node.right
			}
			else { }
		}
	}
	if found { return ceiling }
	return none
}

fn (mut tree Tree[K, V]) clear() {
	tree.root = unsafe { nil }
	tree.size = 0
}

fn (tree Tree[K, V]) to_string() string {
	mut str := "RedBlackTree\n"
	if !tree.empty() {
		output[K, V](tree.root, "", true, mut &str)
	}
	return str
}

fn (node &Node[K, V]) to_string() string {
	return "${node.key}: ${node.value}"
}

fn output[K, V](node &Node[K, V], prefix string, is_tail bool, mut str &string) {
	if node.right != unsafe { nil } {
		mut new_prefix := prefix
		if is_tail { new_prefix = "${new_prefix}|   " } else { new_prefix = "${new_prefix}    " }
		output[K, V](node.right, new_prefix, false, mut str)
	}
	str = "${str}${prefix}"
	if is_tail { str = "${str}└── " } else { str = "${str}┌── " }
	str = "${str}${node.to_string()}\n"
	if node.left != unsafe { nil } {
		mut new_prefix := prefix
		if is_tail { new_prefix = "${new_prefix}    " } else { new_prefix = "${new_prefix}|   " }
		output[K, V](node.left, new_prefix, true, mut str)
	}
}

fn (tree Tree[K, V]) lookup(key K) ?&Node[K, V] {
	mut node := tree.root
	for node != unsafe { nil } {
		compare := tree.cmp(key, node.key)
		match true {
			compare == 0 {
				return node
			}
			compare < 0 {
				node = node.left
			}
			compare > 0 {
				node = node.right
			}
			else { }
		}
	}
	return none
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
	if node == unsafe { nil } || node.parent.left == unsafe { nil } || node.parent == unsafe { nil } {
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
	if grandparent == unsafe { nil } || grandparent.left == unsafe { nil } || node.parent.right == unsafe { nil } { return }
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

fn (mut node Node[K, V]) maximum_node() &Node[K, V] {
	if node == unsafe { nil } { return unsafe { nil } }
	for node.right != unsafe { nil } {
		node = node.right
	}
	return node
}

fn (mut tree Tree[K, V]) delete_case_1(mut node &Node[K, V]) {
	if node.parent == unsafe { nil } {
		return
	}
	tree.delete_case_2(mut node)
}

fn (mut tree Tree[K, V]) delete_case_2(mut node &Node[K, V]) {
	mut sibling := node.sibling()
	if node_color[K, V](sibling) == red {
		node.parent.color = red
		sibling.color = black
		if node == node.parent.left {
			tree.rotate_left(mut node.parent)
		} else {
			tree.rotate_right(mut node.parent)
		}
	}
	tree.delete_case_3(mut node)
}

fn (mut tree Tree[K, V]) delete_case_3(mut node &Node[K, V]) {
	mut sibling := node.sibling()
	if node_color[K, V](node.parent) == black &&
		node_color[K, V](sibling) == black &&
		node_color[K, V](sibling.left) == black &&
		node_color[K, V](sibling.right) == black {
		sibling.color = red
		tree.delete_case_1(mut node.parent)
		return
	}
	tree.delete_case_4(mut node)
}

fn (mut tree Tree[K, V]) delete_case_4(mut node &Node[K, V]) {
	mut sibling := node.sibling()
	if node_color[K, V](node.parent) == red &&
		node_color[K, V](sibling) == black &&
		node_color[K, V](sibling.left) == black &&
		node_color[K, V](sibling.right) == black {
		sibling.color = red
		node.parent.color = black
		return
	}
	tree.delete_case_5(mut node)
}

fn (mut tree Tree[K, V]) delete_case_5(mut node &Node[K, V]) {
	mut sibling := node.sibling()
	if node == node.parent.left &&
		node_color[K, V](sibling) == black &&
		node_color[K, V](sibling.left) == red &&
		node_color[K, V](sibling.right) == black {
		sibling.color = red
		sibling.left.color = black
		tree.rotate_right(mut sibling)
	} else if node == node.parent.right &&
		node_color[K, V](sibling) == black &&
		node_color[K, V](sibling.right) == red &&
		node_color[K, V](sibling.left) == black {
		sibling.color = red
		sibling.right.color = black
		tree.rotate_left(mut sibling)
	}
	tree.delete_case_6(mut node)
}

fn (mut tree Tree[K, V]) delete_case_6(mut node &Node[K, V]) {
	mut sibling := node.sibling()
	sibling.color = node_color[K, V](node.parent)
	node.parent.color = black
	if node == node.parent.left && node_color[K, V](sibling.right) == red {
		sibling.right.color = black
		tree.rotate_left(mut node.parent)
	} else if node_color[K, V](sibling.left) == red {
		sibling.left.color = black
		tree.rotate_right(mut node.parent)
	}
}

fn node_color[K, V](node ?&Node[K, V]) Color {
	if n := node {
		if n == unsafe { nil } { return black }
		return n.color
	}
	return black
}

