module main

fn test_resolve_file_paths_returns_realistic_results() {
	mut mock_modal := FileFinderModal{
		file_paths: [
			'./src/project/main.v',
			'./src/project/lib/some_utilities.v',
		]
	}

	mock_modal.search.query = 'some'
	assert mock_modal.resolve_file_paths().map(it.content) == [
		'./src/project/lib/some_utilities.v',
		'./src/project/main.v',
	]

	mock_modal.search.query = 'mai'
	assert mock_modal.resolve_file_paths().map(it.content) == [
		'./src/project/main.v',
		'./src/project/lib/some_utilities.v',
	]

	mock_modal.search.query = 'proj'
	assert mock_modal.resolve_file_paths().map(it.content) == [
		'./src/project/main.v',
		'./src/project/lib/some_utilities.v',
	]

	mock_modal.search.query = ''
	assert mock_modal.resolve_file_paths().map(it.content) == [
		'./src/project/main.v',
		'./src/project/lib/some_utilities.v',
	]

	mock_modal.search.query = 'zkf'
	assert mock_modal.resolve_file_paths().map(it.content) == [
		'./src/project/lib/some_utilities.v',
		'./src/project/main.v',
	]
}

fn test_fuzzy_searching_is_operational() {
	mut mock_modal := FileFinderModal{
		file_paths: [
			'./src/project/main.v',
			'./src/project/lib/some_utilities.v',
		]
	}

	mock_modal.search.query = 'ut'
	assert mock_modal.resolve_file_paths().map(it.content) == [
		'./src/project/lib/some_utilities.v',
		'./src/project/main.v',
	]
}
