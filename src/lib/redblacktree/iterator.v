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
		left := iterator.tree.left()
		if left == unsafe { nil } {
			on_end[K, V](mut iterator)
			return none
		}
		iterator.node = left
		on_between[K, V](mut iterator)
		return iterator.node
	}

	if iterator.node.right != unsafe { nil } {
		iterator.node = iterator.node.right
		for iterator.node.left != unsafe { nil } {
			iterator.node = iterator.node.left
		}
		on_between[K, V](mut iterator)
		return iterator.node
	}

	if iterator.node.parent != unsafe { nil } {
		node := iterator.node
		iterator.node = iterator.node.parent
		if node == iterator.node.left {
			on_between[K, V](mut iterator)
			return iterator.node
		}
	}

	return none
}
