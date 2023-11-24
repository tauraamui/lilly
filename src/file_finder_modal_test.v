module main

fn test_resolve_file_paths_returns_realistic_results() {
	mut mock_modal := FileFinderModal{
		file_paths: [
			"./src/project/main.v",
			"./src/project/lib/some_utilities.v"
		]
	}

	mock_modal.search.query = "some"
	assert mock_modal.resolve_file_paths() == [
		"./src/project/lib/some_utilities.v"
	]

	mock_modal.search.query = "mai"
	assert mock_modal.resolve_file_paths() == [
		"./src/project/main.v",
	]

	mock_modal.search.query = "proj"
	assert mock_modal.resolve_file_paths() == [
		"./src/project/main.v",
		"./src/project/lib/some_utilities.v"
	]
}
