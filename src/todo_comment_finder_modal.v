module main

import log

const max_height = 30

struct TodoCommentFinderModal {
	log log.Log
pub:
	title       string
	file_path   string
	@[required]
	close_fn    ?fn()
mut:
	search TodoCommentSearch
}

struct TodoCommentSearch {
mut:
	query    string
	cursor_x int
}
