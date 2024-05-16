module redblacktree

type Position = u8

pub struct Iterator[K, V] {
mut:
	tree     &Tree[K, V]
	node     &Node[K, V]
	position Position
}

const begin   = Position(0)
const between = Position(1)
const end     = Position(2)

fn (tree Tree[K, V]) iterator[K, V]() &Iterator[K, V] {
	return &Iterator[K, V]{ tree: &tree, node: unsafe { nil }, position: begin }
}

fn on_end[K, V](mut it &Iterator[K, V]) {
	it.node = unsafe { nil }
	it.position = end
}

fn on_between[K, V](mut it &Iterator[K, V]) {
	it.position = between
}

fn (mut iterator Iterator[K, V]) next() ?&Node[K, V] {
	if iterator.position == end {
		on_end[K, V](mut iterator)
		return none
	}

	if iterator.position == begin {
		if left_node := iterator.tree.left() {
			iterator.node = left_node
			on_between[K, V](mut iterator)
			return iterator.node
		}
	}

	if right_node := iterator.node.right {
		iterator.node = right_node
		for iterator.node.left != none {
			if left_node := iterator.node.left {
				iterator.node = left_node
			}
		}
		on_between[K, V](mut iterator)
		return iterator.node
	}

	for iterator.node.parent != none {
		node := iterator.node
		if parent_node := iterator.node.parent {
			iterator.node = parent_node
		}
		if left_node := iterator.node.left {
			if node == left_node {
				on_between[K, V](mut iterator)
				return iterator.node
			}
		}
	}

	return none
}

