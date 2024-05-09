module redblacktree

fn test_alloc() {
	assert black == true
	assert red   == false
}

fn cmp(x int, y int) int {
	return 0
}

fn test_new_tree() {
	mut rbtree := Tree.new[int, string](cmp)
	rbtree.put(1, "A")
}
