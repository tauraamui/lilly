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

module main

import os
import time

fn test_validate_new_file_path_rejects_empty_value() {
	if _ := validate_new_file_path('') {
		assert false, 'expected empty path to be rejected'
	} else {
		assert err.msg() == 'path is required'
	}
}

fn test_validate_new_file_path_rejects_existing_file() {
	temp_root := os.join_path(os.temp_dir(), 'lilly-new-file-dialog-${time.now().unix_micro()}')
	os.mkdir_all(temp_root) or { panic(err) }
	defer { os.rmdir_all(temp_root) or {} }

	existing_file := os.join_path(temp_root, 'existing.txt')
	os.write_file(existing_file, '') or { panic(err) }

	if _ := validate_new_file_path(existing_file) {
		assert false, 'expected existing file to be rejected'
	} else {
		assert err.msg() == 'file already exists'
	}
}

fn test_validate_new_file_path_rejects_missing_parent_directory() {
	temp_root := os.join_path(os.temp_dir(), 'lilly-new-file-dialog-${time.now().unix_micro()}')
	os.mkdir_all(temp_root) or { panic(err) }
	defer { os.rmdir_all(temp_root) or {} }

	missing_parent_path := os.join_path(temp_root, 'missing', 'new.txt')

	if _ := validate_new_file_path(missing_parent_path) {
		assert false, 'expected missing parent directory to be rejected'
	} else {
		assert err.msg() == 'parent directory does not exist'
	}
}

fn test_validate_new_file_path_returns_absolute_path_for_valid_input() {
	temp_root := os.join_path(os.temp_dir(), 'lilly-new-file-dialog-${time.now().unix_micro()}')
	os.mkdir_all(temp_root) or { panic(err) }
	defer { os.rmdir_all(temp_root) or {} }

	new_file_path := os.join_path(temp_root, 'new-file.txt')
	resolved := validate_new_file_path(new_file_path) or { panic(err) }
	assert resolved == os.abs_path(new_file_path)
}
