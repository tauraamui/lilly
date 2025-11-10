module files

const mock_small_list = [
	"test-file.txt"
	"main.v"
	"main_test.v"
	"foo.v"
	"bar.v"
	".gitignore"
]

fn mock_lister(root string) ![]string {
	return mock_small_list
}

fn test_stdlib_search() {
	mut stdlib_finder := StdlibBasedFinder{ ls: mock_lister }
	stdlib_finder.search("./dev/null")!
	assert stdlib_finder.files() == mock_small_list
}

