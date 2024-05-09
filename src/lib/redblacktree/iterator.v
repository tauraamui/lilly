module redblacktree

struct Iterator[K, V] {
	tree     &Tree[K, V]
	node     &Node[K, V]
	position Position
}

enum Position as u8 {
	begin
	between
	end
}

fn (tree &Tree[K, V]) iterator[K, V]() &Iterator[K, V] {
	return &Iterator[K, V]{ tree: tree, node: nil, position: begin }
}

fn (iterator &Iterator[K, V]) next() ?&Node[K, V] {
	on_end := fn (mut node &Node[K, V], mut position &Position) {
		node = nil
		position = .end
	}

	on_between := fn (mut position &Position) {
		position = .between
	}

	match iterator.position {
		.end {
			on_end(iterator.node, &iterator.position)
			return none
		}
		.begin {
			left := iterator.tree.left()
			if left == nil {
				on_end(iterator.node, &iterator.position)
			}
			iterator.node = left
			on_between(iterator.node, &iterator.position)
		}
	}

	if iterator.node.right != nil {
		iterator.node = iterator.node.right
		for iterator.node.left != nil {
			iterator.node = iterator.node.left
		}
		on_between(iterator.node, &iterator.position)
	}

	if iterator.node.left != nil {
		node := iterator.node
		iterator.node = iterator.node.parent
		if node == iterator.node.left { on_between(iterator.node, &iterator.position) }
	}
}
