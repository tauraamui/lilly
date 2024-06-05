module redblacktree

fn test_alloc() {
	assert black == true
	assert red   == false
}

fn cmp(x int, y int) int {
	if x == y { return 0 }
	if x < y { return -1 }
	if x > y { return 1 }
	return 0
}

// Make an insert of one element and check if the rbt is able to locate it
fn test_insert_into_rbt_one() {
	mut rbt := RBTree.new[int, string](cmp)
	assert rbt.insert(10, "Line 10")
	assert rbt.contains(10)
	assert rbt.contains(20) == false
}

// Make the insert of more elements into rbt and check if it is able to locate them all
fn test_insert_into_rbt_two() {
	mut rbt := RBTree.new[int, string](cmp)
	assert rbt.insert(10, "Line 10")
	assert rbt.insert(20, "Line 20")
	assert rbt.insert(9, "Line 9")

	assert rbt.contains(9)
	assert rbt.contains(10)
	assert rbt.contains(20)
	assert rbt.contains(11) == false
}

// Ensure the in_order_traversals list return the results correctly
fn test_in_order_rbt_visit_one() {
	mut rbt := RBTree.new[int, string](cmp)
	assert rbt.insert(10, "Line 10")
	assert rbt.insert(20, "Line 20")
	assert rbt.insert(21, "Line 21")
	assert rbt.insert(1, "Line 1")

	assert rbt.in_order_traversal() == [1, 10, 20, 21]
}

/*
fn test_red_black_tree_get() {
	mut tree := Tree.new[int, string](cmp)
	assert tree.size() == 0, 'expected tree size of 0'

	mut rbtree := RBTree.new[int, string](cmp)
	assert rbtree.insert(1, "f")
	assert rbtree.insert(3, "dw")

	if node_two := tree.get_node(2) {
		assert node_two.size() == 0, 'expected node sub tree size of 0'
	}

	tree.put(1, "x") // 1->x
	tree.put(2, "b") // 1->x, 2->b (in order)
	tree.put(1, "a") // 1->a, 2->b (in order, replacement)
	tree.put(4, "d") // 1->a, 2->b, 3->c, 4->d (in order)
	tree.put(3, "c") // 1->a, 2->b, 3->c (in order)
	tree.put(5, "e") // 1->a, 2->b, 3->c, 4->d, 5->e (in order)
	tree.put(6, "f") // 1->a, 2->b, 3->c, 4->d, 5->e, 6->f (in order)

	println(tree.to_string())
	// RedBlackTree
	// |               ┌── 6: f
	// |           ┌── 5: e
	// |       ┌── 4: d
	// |       |   └── 3: c
	// |   ┌── 2: b
	// └── 1: a

	assert 3 == 5

	assert tree.size() == 6, 'expected tree size of 6'

	if node_four := tree.get_node(4) {
		assert node_four.size() == 3, 'expected sub branch size of 3 from node 4'
	}

	if node_two := tree.get_node(2) {
		assert node_two.size() == 5, 'expected sub branch size of 5 from node 2'
	}

	if node_eight := tree.get_node(8) {
		assert node_eight.size() == 0, 'expected sub branch size of 0 from node 8'
	}
}

@[assert_continues]
fn test_red_black_tree_put() {
	mut tree := Tree.new[int, string](cmp)

	tree.put(5, "e")
	tree.put(6, "f")
	tree.put(7, "g")
	tree.put(3, "c")
	tree.put(4, "d")
	tree.put(1, "x")
	tree.put(2, "b")
	tree.put(1, "a") // overwrite

	println(tree.to_string())

	assert tree.size() == 7, 'expected tree size of 7'
	assert tree.keys() == [1, 2, 3, 4, 5, 6, 7], 'expected tree node keys'
	assert tree.values() == ["a", "b", "c", "d", "e", "f", "g"], 'expected tree node values'
}
*/
