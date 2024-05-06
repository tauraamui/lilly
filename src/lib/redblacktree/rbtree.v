module redblacktree

type Color = bool

const black = Color(true)
const red   = Color(false)

type Comparator[K] = fn (x K, y K) int

struct Tree[K, V] {
mut:
	root &Node[K, V]
	size int
	cmp  Comparator[K]
}

struct Node[K, V] {
mut:
	key   K
	value V
	color Color
	left   &Node[K, V]
	right  &Node[K, V]
	parent &Node[K, V]
}

fn new[K, V](cmp Comparator[K]) &Tree[K, V] {
	return &Tree[K, V]{ cmp: cmp }
}

fn (mut tree Tree[K, V]) put(key K, value V) {
	if tree.root == nil {
		tree.root = &Node[K, V]{key: key, value: value, color: red}
		// tree.insertCase1(tree.root)
		tree.size += 1
		return
	}

	node := tree.Root
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
				loop = false
			}
		}
	}
}
