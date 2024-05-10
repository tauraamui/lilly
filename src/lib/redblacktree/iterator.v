module redblacktree

type Position = u8

pub struct Iterator[K, V] {
	tree     &Tree[K, V]
	node     &Node[K, V]
	position Position
}

const begin   = Position(0)
const between = Position(1)
const end     = Position(2)

fn (tree Tree[K, V]) iterator() &Iterator[K, V] {
	return &Iterator[K, V]{ tree: tree, node: unsafe { nil }, position: begin }
}

fn (iterator &Iterator[K, V]) next() ?&Node[K, V] {
	on_end := fn (mut it &Iterator[K, V]) {
		it.node = unsafe { nil }
		iterator.position = end
	}
	on_between := fn (mut it &Iterator[K, V]) {
		it.position = between
	}
	if iterator.position == end {
		on_end(mut iterator)
		return none
	}

	if iterator.position == begin {
		left := iterator.tree.left()
		if left == unsafe { nil } {
			on_end(mut iterator)
			return
		}
		iterator.node = left
	}
}
