module main

import lib.draw

fn test_current_selection_gets_zeros_on_search_term_amend() {
	mut mock_modal := FileFinderModal{
		file_paths: [
			'./src/project/main.v',
			'./src/project/lib/some_utilities.v',
		]
	}

	assert mock_modal.current_selection == 0
	mock_modal.on_key_down(draw.Event{utf8: "d"}, mut Editor{})
	assert mock_modal.current_selection == 0

	mock_modal.on_key_down(draw.Event{code: .down}, mut Editor{})
	assert mock_modal.current_selection == 1

	mock_modal.on_key_down(draw.Event{utf8: "r"}, mut Editor{})
	assert mock_modal.current_selection == 0
}

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
