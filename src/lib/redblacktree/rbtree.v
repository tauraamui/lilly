module redblacktree

import strings

type Color = bool

const black = Color(true)
const red   = Color(false)

pub type Comparator[K] = fn (x K, y K) int

@[heap]
pub struct Tree[K, V] {
mut:
	root ?&Node[K, V]
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
	return &Tree[K, V]{ root: none, cmp: cmp }
}

pub fn (mut tree Tree[K, V]) put(key K, value V) {
	mut inserted_node := &Node[K, V](unsafe { nil })
	if mut node := tree.root {
		mut loop := true
		for loop {
			compare := tree.cmp(key, node.key)
			if compare == 0 {
				node.key = key
				node.value = value
				return
			}
			if compare < 0 {
				if left_node := node.left {
					node = left_node
				} else {
					node.left = &Node[K, V]{ key: key, value: value, color: red }
					if left_node := node.left {
						inserted_node = left_node
					}
					loop = false
				}
			} else if compare > 0 {
				if right_node := node.right {
					node = right_node
				} else {
					node.right = &Node[K, V]{ key: key, value: value, color: red }
					if right_node := node.right {
						inserted_node = right_node
					}
					loop = false
				}
			}
		}
	} else {
		tree.root = &Node[K, V]{ key: key, value: value, color: red }
		if tree_root := tree.root {
			inserted_node = tree_root
		}
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

/*
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
*/

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
	if left_node := node.left {
		size += left_node.size()
	}
	if right_node := node.right {
		size += right_node.size()
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

fn (mut tree Tree[K, V]) left() ?&Node[K, V] {
	mut parent := &Node[K, V](unsafe { nil })
	if mut current := tree.root {
		parent = current
		if left := current.left {
			current = left
		}
		return parent
	}
	return none
}

fn (mut tree Tree[K, V]) right() ?&Node[K, V] {
	mut parent := &Node[K, V](unsafe { nil })
	if mut current := tree.root {
		parent = current
		if right := current.right {
			current = right
		}
		return parent
	}
	return none
}

fn (mut tree Tree[K, V]) floor(key K) ?&Node[K, V] {
	mut floor := ?&Node[K, V](none)
	mut node := ?&Node[K, V](tree.root)
	for node != none {
		compare := tree.cmp(key, node?.key)
		match true {
			compare == 0 {
				return node
			}
			compare < 0 {
				node = node?.left
			}
			compare > 0 {
				floor = node
				node = node?.right
			}
			else { }
		}
	}
	return floor
}

fn (mut tree Tree[K, V]) ceiling(key K) ?&Node[K, V] {
	mut ceiling := ?&Node[K, V](none)
	mut node := ?&Node[K, V](tree.root)
	for node != none {
		compare := tree.cmp(key, node?.key)
		match true {
			compare == 0 {
				return node
			}
			compare < 0 {
				ceiling = node
				node = node?.left
			}
			compare > 0 {
				node = node?.right
			}
			else { }
		}
	}
	return ceiling
}

fn (mut tree Tree[K, V]) clear() {
	tree.root = none
	tree.size = 0
}

fn (tree Tree[K, V]) to_string() string {
	mut str := "RedBlackTree\n"
	if !tree.empty() {
		if root := tree.root {
			output[K, V](root, "", true, mut &str)
		}
	}
	return str
}

fn (node &Node[K, V]) to_string() string {
	return "${node.key}: ${node.value}"
}

fn output[K, V](node &Node[K, V], prefix string, is_tail bool, mut str &string) {
	if right_node := node.right {
		mut new_prefix := prefix
		if is_tail { new_prefix = "${new_prefix}|   " } else { new_prefix = "${new_prefix}    " }
		output[K, V](right_node, new_prefix, false, mut str)
	}
	str = "${str}${prefix}"
	if is_tail { str = "${str}└── " } else { str = "${str}┌── " }
	str = "${str}${node.to_string()}\n"
	if left_node := node.left {
		mut new_prefix := prefix
		if is_tail { new_prefix = "${new_prefix}    " } else { new_prefix = "${new_prefix}|   " }
		output[K, V](left_node, new_prefix, true, mut str)
	}
}

fn (tree Tree[K, V]) lookup(key K) ?&Node[K, V] {
	mut node := ?&Node[K, V](tree.root)
	for node != none {
		compare := tree.cmp(key, node?.key)
		match true {
			compare == 0 {
				return node
			}
			compare < 0 {
				node = node?.left
			}
			compare > 0 {
				node = node?.right
			}
			else { }
		}
	}
	return none
}

fn (node &Node[K, V]) grandparent() ?&Node[K, V] {
	if parent_node := node.parent {
		return parent_node.parent
	}
	return none
}

fn (node &Node[K, V]) uncle() ?&Node[K, V] {
	if parent_node := node.parent {
		if parent_parent_node := parent_node.parent {
			return parent_node.sibling()
		}
	}
	return none
}

fn (node &Node[K, V]) sibling() ?&Node[K, V] {
	if parent_node := node.parent {
		if left_parent_node := parent_node.left {
			if node == left_parent_node {
				return parent_node.right
			}
		}
		return parent_node.left
	}
	return none
}

fn (mut tree Tree[K, V]) rotate_left(mut node &Node[K, V]) {
	if mut right_node := node.right {
		tree.replace_node(mut node, mut right_node)
		node.right = right_node.left
		if mut right_left_node := right_node.left {
			right_left_node.parent = node
		}
		right_node.left = node
		node.parent = right_node
	}
}

fn (mut tree Tree[K, V]) rotate_right(mut node &Node[K, V]) {
	if mut left_node := node.left {
		tree.replace_node(mut node, mut left_node)
		node.left = left_node.right
		if mut left_right_node := left_node.right {
			left_right_node.parent = node
		}
		left_node.right = node
		node.parent = left_node
	}
}

fn (mut tree Tree[K, V]) replace_node(mut old &Node[K, V], mut new &Node[K, V]) {
	if mut old_parent := old.parent {
		if old_parent_left_node := old_parent.left {
			if old == old_parent_left_node {
				old_parent.left = new
			} else {
				old_parent.right = new
			}
		}
		new.parent = old_parent
	}
}

fn (mut tree Tree[K, V]) insert_case_1(mut node &Node[K, V]) {
	if parent_node := node.parent {
		tree.insert_case_2(mut node)
	} else {
		node.color = black
	}
}

fn (mut tree Tree[K, V]) insert_case_2(mut node &Node[K, V]) {
	if node_color[K, V](node.parent) == black {
		return
	}
	tree.insert_case_3(mut node)
}

fn (mut tree Tree[K, V]) insert_case_3(mut node &Node[K, V]) {
	if mut uncle_node := node.uncle() {
		if node_color[K, V](uncle_node) == red {
			if mut parent_node := node.parent {
				parent_node.color = black
				uncle_node.color = black
				if mut grandparent_node := node.grandparent() {
					grandparent_node.color = red
					tree.insert_case_1(mut grandparent_node)
				}
			}
		} else {
			tree.insert_case_4(mut node)
		}
	}
}

fn (mut tree Tree[K, V]) insert_case_4(mut node &Node[K, V]) {
	if grandparent_node := node.grandparent() {
		if mut parent_node := node.parent {
			if parent_right_node := parent_node.right {
				if grandparent_left_node := grandparent_node.left {
					if node == parent_right_node && parent_node == grandparent_left_node {
						tree.rotate_left(mut parent_node)
						if left := node.left {
							node = left
						}
					}
				}
			} else {
				if parent_left_node := parent_node.left {
					if grandparent_right_node := grandparent_node.right {
						if node == parent_left_node && parent_node == grandparent_right_node {
							tree.rotate_right(mut parent_node)
							if right := node.right {
								node = right
							}
						}
					}
				}
			}
		}
	}
	tree.insert_case_5(mut node)
}

fn (mut tree Tree[K, V]) insert_case_5(mut node &Node[K, V]) {
	if mut parent_node := node.parent {
		parent_node.color = black
		if mut grandparent_node := node.grandparent() {
			grandparent_node.color = red
			if parent_left_node := parent_node.left {
				if parent_right_node := parent_node.right {
					if grandparent_left_node := grandparent_node.left {
						if grandparent_right_node := grandparent_node.right {
							if node == parent_left_node && parent_node == grandparent_left_node {
								tree.rotate_right(mut grandparent_node)
							} else if node == parent_right_node && parent_node == grandparent_right_node {
								tree.rotate_left(mut grandparent_node)
							}
						}
					}
				}
			}
		}
	}
}

fn (mut node Node[K, V]) maximum_node() &Node[K, V] {
	for node.right != none {
		if right_node := node.right {
			node = right_node
		}
	}
	return node
}

fn (mut tree Tree[K, V]) delete_case_1(mut node &Node[K, V]) {
	if parent_node := node.parent {
		tree.delete_case_2(mut node)
	}
}

fn (mut tree Tree[K, V]) delete_case_2(mut node &Node[K, V]) {
	if mut sibling := node.sibling() {
		if node_color[K, V](sibling) == red {
			if mut parent_node := node.parent {
				parent_node.color = red
				sibling.color = black
				if parent_left_node := parent_node.left {
					if node == parent_left_node {
						tree.rotate_left(mut parent_node)
					} else {
						tree.rotate_right(mut parent_node)
					}
				}
			}
		}
	}
	tree.delete_case_3(mut node)
}

fn (mut tree Tree[K, V]) delete_case_3(mut node &Node[K, V]) {
	if mut sibling := node.sibling() {
		if node_color[K, V](node.parent) == black &&
			node_color[K, V](sibling) == black &&
			node_color[K, V](sibling.left) == black &&
			node_color[K, V](sibling.right) == black {
			sibling.color = red
			if mut parent_node := node.parent {
				tree.delete_case_1(mut parent_node)
			}
			return
		}
	}
	tree.delete_case_4(mut node)
}

fn (mut tree Tree[K, V]) delete_case_4(mut node &Node[K, V]) {
	if mut sibling := node.sibling() {
		if node_color[K, V](node.parent) == red &&
			node_color[K, V](sibling) == black &&
			node_color[K, V](sibling.left) == black &&
			node_color[K, V](sibling.right) == black {
			sibling.color = red
			if mut parent_node := node.parent {
				parent_node.color = black
			}
			return
		}
	}
	tree.delete_case_5(mut node)
}

fn (mut tree Tree[K, V]) delete_case_5(mut node &Node[K, V]) {
	if mut sibling := node.sibling() {
		if parent_node := node.parent {
			if parent_left_node := parent_node.left {
				if parent_right_node := parent_node.right {
					if node == parent_left_node &&
						node_color[K, V](sibling) == black &&
						node_color[K, V](sibling.left) == red &&
						node_color[K, V](sibling.right) == black {
						sibling.color = red
						if mut sibling_left_node := sibling.left {
							sibling_left_node.color = black
						}
						tree.rotate_right(mut sibling)
					} else if node == parent_right_node &&
						node_color[K, V](sibling) == black &&
						node_color[K, V](sibling.right) == red &&
						node_color[K, V](sibling.left) == black {
						sibling.color = red
						if mut sibling_right_node := sibling.right {
							sibling_right_node.color = black
						}
						tree.rotate_left(mut sibling)
					}
				}
			}
			tree.delete_case_6(mut node)
		}
	}
}

fn (mut tree Tree[K, V]) delete_case_6(mut node &Node[K, V]) {
	if mut sibling := node.sibling() {
		if mut parent_node := node.parent {
			sibling.color = node_color[K, V](parent_node)
			parent_node.color = black
			if parent_left_node := parent_node.left {
				if node == parent_left_node && node_color[K, V](sibling.right) == red {
					if mut sibling_right_node := sibling.right {
						sibling_right_node.color = black
						tree.rotate_left(mut parent_node)
					}
				} else if node_color[K, V](sibling.left) == red {
					if mut sibling_left_node := sibling.left {
						sibling_left_node.color = black
						tree.rotate_right(mut parent_node)
					}
				}
			}
		}
	}
}

fn node_color[K, V](node ?&Node[K, V]) Color {
	if nnode := node {
		return nnode.color
	}
	return black
}

