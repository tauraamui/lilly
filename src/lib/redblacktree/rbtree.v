module redblacktree

type Color = bool

const black = Color(true)
const red   = Color(false)

pub type Comparator[K] = fn (x K, y K) int

pub struct Tree[K, V] {
mut:
	root &Node[K, V]
	size int
	cmp  Comparator[K]
}

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
	return &Tree[K, V]{ cmp: cmp }
}

pub fn (mut tree Tree[K, V]) put(key K, value V) {
	if tree.root == nil {
		tree.root = &Node[K, V]{key: key, value: value, color: red}
		// tree.insert_case_1(tree.root)
		tree.size += 1
		return
	}

	mut node := tree.Root
	mut inserted_node := &Node{}
	mut loop := true
	for loop {
		compare := tree.cmp(key, node.key)
		if compare == 0 {
			node.key = key
			node.value = value
			return
		}

		if compare < 0 {
			if node.left == nil {
				node.left = &Node[K, V]{ key: key, value: value, color: red }
				inserted_node = node.left
				loop = false
				node = node.left
				continue
			}
			node = node.left
			continue
		}

		if compare > 0 {
			if node.right == nil {
				node.right = &Node[K, V]{ key: key, value: value, color: red }
				inserted_node = node.right
				loop = false
				continue
			}
			node = node.right
		}
	}
	// tree.insert_case_1(inserted_node)
}

pub fn (mut tree Tree[K, V]) get(key K) ?V {
	node := tree.lookup(key)
	if node != nil {
		return node.value
	}
	return none
}

pub fn (mut tree Tree[K, V]) get_node(key K) &Node[K, V] {
	return tree.lookup(key)
}

pub fn (mut tree Tree[K, V]) remove(key K) {
	mut child := &Node{}
	node := tree.lookup(key)
	if node == nil {
		return
	}

	if node.left != nil && node.right != nil {
		pred := node.left.maximum_node()
		node.key = pred.key
		node.value = pred.value
		node = pred
	}

	if node.left == nil || node.right == nil {
		child = node.right
		if child == nil {
			child = node.left
		}
		if node.color == black {
			node.color = node_color(child)
			// tree.delete_case_1(node)
		}
		// tree.replace_node(node, child)
		if node.parent == nil && child != nil {
			child.color = black
		}
	}
	tree.size -= 1
}

pub fn (tree Tree[K, V]) empty() bool { return tree.size == 0 }

pub fn (tree Tree[K, V]) size() int { return tree.size }

pub fn (node &Node[K, V]) size() int {
	if node == nil { return 0 }
	mut size := 1
	if node.left != nil { size += node.left.size() }
	if node.right != nil { size += node.right.size() }
	return size
}

pub fn (tree Tree[K, V]) keys() []K {
	mut keys := []K{ len: tree.size }
	it := tree.iterator()
	for i, node in it {
		keys[i] = node.key()
	}
	return keys
}

pub fn (tree Tree[K, V]) values() []V {
	mut values := []V{ len: tree.size }
	it := tree.iterator()
	for i, node in it {
		keys[i] = node.value()
	}
	return values
}

pub fn (tree Tree[K, V]) left() &Node[K, V] {
	mut parent := tree.root
	mut current := parent
	for current != nil {
		parent = current
		current = current.left
	}
	return parent
}

pub fn (tree Tree[K, V]) right() &Node[K, V] {
	mut parent := tree.root
	mut current := parent
	for current != nil {
		parent = current
		current = current.right
	}
	return parent
}

pub fn (tree Tree[K, V]) floor(key K) ?&Node[K, V] {
}

fn (mut tree Tree[K, V]) lookup(key K) &Node[K, V] {
	node := tree.root
	for node != nil {
		compare := tree.cmp(key, node.key)
		if compare == 0 { return node }
		if compare < 0 { node = node.left; continue }
		if compare > 0 { node = node.right; continue }
	}
	return nil
}

fn (mut node Node[K, V]) maximum_node() &Node[K, V] {
	if node == nil { return nil }
	for node.right != nil {
		node = node.right
	}
	return node
}

fn node_color[K, V](node &Node[K, V]) Color {
	if node == nil { return black }
	return node.color
}
