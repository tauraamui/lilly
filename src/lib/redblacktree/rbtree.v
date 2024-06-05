module redblacktree

import strings

type Color = bool

const black = Color(true)
const red   = Color(false)

pub type Comparator[K] = fn (x K, y K) int

@[heap]
struct RBTreeNode[K, V] {
mut:
	is_init bool
	key    K
	value  V
	color  Color
	left   &RBTreeNode[K, V] = unsafe { 0 }
	right  &RBTreeNode[K, V] = unsafe { 0 }
	parent &RBTreeNode[K, V] = unsafe { 0 }
}

fn new_root_node[K, V](key K, value V) &RBTreeNode[K, V] {
	return &RBTreeNode[K, V]{
		is_init: true
		key: key
		value: value
		left: new_none_node[K, V](false)
		right: new_none_node[K, V](false)
		parent: new_none_node[K, V](false)
	}
}

fn new_node[K, V](parent &RBTreeNode[K, V], key K, value V) &RBTreeNode[K, V] {
	return &RBTreeNode[K, V]{
		is_init: true
		key: key
		value: value
		left: unsafe { 0 }
		right: unsafe { 0 }
		parent: parent
	}
}

fn new_none_node[K, V](init bool) &RBTreeNode[K, V] {
	return &RBTreeNode[K, V]{
		is_init: init
		left: unsafe { 0 }
		right: unsafe { 0 }
		parent: unsafe { 0 }
	}
}

fn (mut node RBTreeNode[K, V]) bind(mut to_bind RBTreeNode[K, V], left bool) {
	node.color = to_bind.color
	node.left = to_bind.left
	node.right = to_bind.right
	node.parent = to_bind.parent
	node.is_init = to_bind.is_init
	to_bind = new_none_node[K, V](false)

}

fn (mut node RBTreeNode[K, V]) grandparent() &RBTreeNode[K, V] {
	if unsafe { node.parent == 0 } {
		return new_none_node[K, V](false)
	}
	return node.parent.parent
}

fn (mut node RBTreeNode[K, V]) uncle() &RBTreeNode[K, V] {
	if unsafe { node.parent == 0 } || unsafe { node.parent.parent == 0 } {
		return new_none_node[K, V](false)
	}
	return node.parent.sibling()
}

fn (mut node RBTreeNode[K, V]) sibling() &RBTreeNode[K, V] {
	if unsafe { node.parent == 0 } {
		return new_none_node[K, V](false)
	}
	if node == node.parent.left {
		return node.parent.right
	}
	return node.parent.left
}

fn (mut rbt RBTree[K, V]) rotate_left[K, V](mut node RBTreeNode[K, V]) {
	mut right := node.right
	rbt.replace_node(mut node, mut right)
	node.right = right.left
	if unsafe { node.left != 0 } && node.left.is_init {
		node.left.parent = node
	}
	right.left = node
	node.parent = right
}

fn (mut rbt RBTree[K, V]) rotate_right[K, V](mut node RBTreeNode[K, V]) {
	mut left := node.left
	rbt.replace_node(mut node, mut left)
	node.left = left.right
	if unsafe { node.right != 0 } && node.right.is_init {
		node.right.parent = node
	}
	left.right = node
	node.parent = left
}

pub struct RBTree[K, V] {
mut:
	cmp Comparator[K]
	root &RBTreeNode[K, V] = unsafe { 0 }
	size int
}

pub fn RBTree.new[K, V](cmp Comparator[K]) &RBTree[K, V] {
	return &RBTree[K, V]{
		root: unsafe { 0 }
		cmp: cmp
	}
}

pub fn (mut rbt RBTree[K, V]) insert(key K, value V) bool {
	if rbt.is_empty() {
		rbt.root = new_root_node(key, value)
		rbt.insert_case_1(mut rbt.root)
		rbt.size += 1
		return true
	}

	return rbt.insert_helper(mut rbt.root, key, value)
}

fn (mut rbt RBTree[K, V]) insert_helper(mut node RBTreeNode[K, V], key K, value V) bool {
	mut inserted_node := new_none_node[K, V](false)
	compare := rbt.cmp(node.key, key)
	if compare < 0 {
		if unsafe { node.right != 0 } && node.right.is_init {
			return rbt.insert_helper(mut node.right, key, value)
		}
		node.right = new_node(node, key, value)
		inserted_node = node.right
		rbt.insert_case_1(mut inserted_node)
		rbt.size += 1
		return true
	} else if compare > 0 {
		if unsafe { node.left != 0 } && node.left.is_init {
			return rbt.insert_helper(mut node.left, key, value)
		}
		node.left = new_node(node, key, value)
		inserted_node = node.left
		rbt.insert_case_1(mut inserted_node)
		rbt.size += 1
		return true
	}
	return false
}

pub fn (mut rbt RBTree[K, V]) contains(key K) bool {
	return rbt.contains_helper(rbt.root, key)
}

fn (mut rbt RBTree[K, V]) contains_helper(node &RBTreeNode[K, V], key K) bool {
	if unsafe { node == 0 } || !node.is_init {
		return false
	}

	compare := rbt.cmp(node.key, key)
	if compare < 0 {
		return rbt.contains_helper(node.right, key)
	} else if compare > 0 {
		return rbt.contains_helper(node.left, key)
	}
	assert node.key == key
	return true
}

pub fn (mut rbt RBTree[K, V]) remove(key K) bool {
	if rbt.is_empty() {
		return false
	}
	return rbt.remove_helper(mut rbt.root, key, false)
}

fn (mut rbt RBTree[K, V]) remove_helper(mut node RBTreeNode[K, V], key K, left bool) bool {
	if !node.is_init {
		return false
	}
	if node.key == key {
		if unsafe { node.left != 0 } && node.left.is_init {
			mut max_node := rbt.get_max_from_right(node.left)
			node.bind(mut max_node, true)
		} else if unsafe { node.right != 0 } && node.right.is_init {
			mut min_node := rbt.get_min_from_left(node.right)
			node.bind(mut min_node, false)
		} else {
			mut parent := node.parent
			if left {
				parent.left = new_none_node[K, V](false)
			} else {
				parent.right = new_none_node[K, V](false)
			}
			node = new_none_node[K, V](false)
		}
		return true
	}

	compare := rbt.cmp(node.key, key)
	if compare < 0 {
		return rbt.remove_helper(mut node.right, key, false)
	}
	return rbt.remove_helper(mut node.left, key, true)
}

fn (mut rbt RBTree[K, V]) get_max_from_right(node &RBTreeNode[K, V]) &RBTreeNode[K, V] {
	if unsafe { node == 0 } {
		return new_none_node[K, V](false)
	}
	right_node := node.right
	if unsafe { right_node == 0 } || !right_node.is_init {
		return node
	}
	return rbt.get_max_from_right(right_node)
}

fn (mut rbt RBTree[K, V]) get_min_from_left(node &RBTreeNode[K, V]) &RBTreeNode[K, V] {
	if unsafe { node == 0 } {
		return new_none_node[K, V](false)
	}
	left_node := node.left
	if unsafe { left_node == 0 } || !left_node.is_init {
		return node
	}
	return rbt.get_min_from_left(left_node)
}

pub fn (rbt &RBTree[K, V]) in_order_traversal() []K {
	mut result := []K{}
	rbt.in_order_traversal_helper(rbt.root, mut result)
	return result
}

fn (rbt &RBTree[K, V]) in_order_traversal_helper(node &RBTreeNode[K, V], mut result []K) {
	if unsafe { node == 0 } || !node.is_init {
		return
	}
	rbt.in_order_traversal_helper(node.left, mut result)
	result << node.key
	rbt.in_order_traversal_helper(node.right, mut result)
}

pub fn (mut rbt RBTree[K, V]) post_order_traversal() []K {
	mut result := []K{}
	rbt.post_order_traversal_helper(rbt.root, mut result)
	return result
}

fn (mut rbt RBTree[K, V]) post_order_traversal_helper(node &RBTreeNode[K, V], mut result []K) {
	if unsafe { node == 0 } || !node.is_init {
		return
	}

	rbt.post_order_traversal_helper(node.left, mut result)
	rbt.post_order_traversal_helper(node.right, mut result)
	result << node.key
}

pub fn (rbt &RBTree[K, V]) pre_order_traversal() []K {
	mut result := []K{}
	rbt.pre_order_traversal_helper(rbt.root, mut result)
	return result
}

fn (rbt &RBTree[K, V]) pre_order_traversal_helper(node &RBTreeNode[K, V], mut result []K) {
	if unsafe { node == 0 } || !node.is_init {
		return
	}

	result << node.key
	rbt.pre_order_traversal_helper(node.left, mut result)
	rbt.pre_order_traversal_helper(node.right, mut result)
}

fn (mut rbt RBTree[K, V]) replace_node(mut old RBTreeNode[K, V], mut new RBTreeNode[K, V]) {
	if unsafe { old.parent != 0 } && old.parent.is_init {
		if old == old.parent.left {
			old.parent.left = new
		} else {
			old.parent.right = new
		}
	}
	if new.is_init {
		new.parent = old.parent
	}
}

fn (mut rbt RBTree[K, V]) insert_case_1(mut node RBTreeNode[K, V]) {
	if !node.parent.is_init {
		node.color = black
		return
	}
	rbt.insert_case_2(mut node)
}

fn (mut rbt RBTree[K, V]) insert_case_2(mut node RBTreeNode[K, V]) {
	if rbnode_color[K, V](node.parent) == black {
		return
	}
	rbt.insert_case_3(mut node)
}

fn (mut rbt RBTree[K, V]) insert_case_3(mut node RBTreeNode[K, V]) {
	mut uncle := node.uncle()
	if rbnode_color[K, V](uncle) == red {
		node.parent.color = black
		uncle.color = black
		node.grandparent().color = red
		rbt.insert_case_1(mut node.grandparent())
		return
	}
	rbt.insert_case_4(mut node)
}

fn (mut rbt RBTree[K, V]) insert_case_4(mut node RBTreeNode[K, V]) {
	mut grandparent := node.grandparent()
	if node == node.parent.right && node.parent == grandparent.left {
		rbt.rotate_left(mut node.parent)
		node = node.left
		rbt.insert_case_5(mut node)
		return
	}

	if unsafe { node.parent.left != 0 } && node.parent.left.is_init && node == node.parent.left && node.parent == grandparent.right {
		rbt.rotate_right(mut node.parent)
		node = node.right
		rbt.insert_case_5(mut node)
	}
}

fn (mut rbt RBTree[K, V]) insert_case_5(mut node RBTreeNode[K, V]) {
	node.parent.color = black
	mut grandparent := node.grandparent()
	grandparent.color = red
	if node == node.parent.left && node.parent == grandparent.left {
		rbt.rotate_right(mut grandparent)
		return
	}
	if node == node.parent.right && node.parent == grandparent.right {
		rbt.rotate_left(mut grandparent)
	}
}

fn (rbt &RBTree[K, V]) get_node(node &RBTreeNode[K, V], key K) &RBTreeNode[K, V] {
	if unsafe { node == 0 } || !node.is_init {
		return new_none_node[K, V](false)
	}

	compare := rbt.cmp(node.key, key)
	if compare == 0 {
		return node
	}

	if compare < 0 {
		return rbt.get_node(node.right, key)
	}

	return rbt.get_node(node.left, key)
}

pub fn (rbt &RBTree[K, V]) to_left(key K) !V {
	if rbt.is_empty() {
		return error('RBTree is empty')
	}
	node := rbt.get_node(rbt.root, key)
	if !node.is_init {
		return error('RBTree is not initialised')
	}
	left_node := node.left
	return left_node.value
}

pub fn (rbt &RBTree[K, V]) to_right(key K) !V {
	if rbt.is_empty() {
		return error('RBTree is empty')
	}
	node := rbt.get_node(rbt.root, key)
	if !node.is_init {
		return error('RBTree is not initialised')
	}
	right_node := node.right
	return right_node.value
}

pub fn (rbt &RBTree[K, V]) is_empty() bool {
	return unsafe { rbt.root == 0 }
}

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

fn rbnode_color[K, V](node RBTreeNode[K, V]) Color {
	if !node.is_init {
		return black
	}
	return node.color
}

fn node_color[K, V](node ?&Node[K, V]) Color {
	if nnode := node {
		return nnode.color
	}
	return black
}

