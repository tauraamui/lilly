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

fn test_red_black_tree_get() {
	mut tree := Tree.new[int, string](cmp)
	assert tree.size() == 0, 'expected tree size of 0'

	if node_two := tree.get_node(2) {
		assert node_two.size() == 0, 'expected node sub tree size of 0'
	}

	tree.put(1, "x") // 1->x
	tree.put(2, "b") // 1->x, 2->b (in order)
	tree.put(1, "a") // 1->a, 2->b (in order, replacement)
	tree.put(3, "c") // 1->a, 2->b, 3->c (in order)
	tree.put(4, "d") // 1->a, 2->b, 3->c, 4->d (in order)
	tree.put(5, "e") // 1->a, 2->b, 3->c, 4->d, 5->e (in order)
	tree.put(6, "f") // 1->a, 2->b, 3->c, 4->d, 5->e, 6->f (in order)

	println(tree.to_string())
	assert 10 == 12
}

fn test_new_tree_with_some_puts() {
	mut rbtree := Tree.new[int, string](cmp)
	rbtree.put(50, "A")
	rbtree.put(30, "B")
	rbtree.put(60, "C")
	println(rbtree.to_string())
	assert 2 == 3
}

