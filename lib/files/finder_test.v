// Copyright 2026 The Lilly Edtior contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

module files

const mock_small_list = [
	'test-file.txt',
	'main.v',
	'main_test.v',
	'foo.v',
	'bar.v',
	'.gitignore',
]

fn mock_lister(root string) ![]string {
	return mock_small_list
}

fn test_stdlib_search() {
	stdlib_finder := StdlibBasedFinder{
		ls:    mock_lister
		files: mock_small_list.clone()
	}
	// stdlib_finder.search("./dev/null")
	assert stdlib_finder.files() == mock_small_list
}
