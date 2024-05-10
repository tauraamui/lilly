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

fn test_new_tree_with_some_puts() {
	mut rbtree := Tree.new[int, string](cmp)
	rbtree.put(50, "A")
	rbtree.put(30, "B")
	rbtree.put(60, "C")
	println(rbtree.to_string())
	assert rbtree.size == 3
}
