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

import os

fn test_is_binary_returns_false_for_plain_text_file() {
	path := os.join_path(os.temp_dir(), 'test_text.txt')
	os.write_file(path, 'hello world\n')!
	defer {
		os.rm(path) or {}
	}
	assert is_binary(path) == false
}

fn test_is_binary_returns_false_for_empty_file() {
	path := os.join_path(os.temp_dir(), 'test_empty.txt')
	os.write_file(path, '')!
	defer {
		os.rm(path) or {}
	}
	assert is_binary(path) == false
}

fn test_is_binary_returns_false_for_shebang_script() {
	path := os.join_path(os.temp_dir(), 'test_script.sh')
	os.write_file(path, '#!/bin/bash\necho hello\n')!
	defer {
		os.rm(path) or {}
	}
	assert is_binary(path) == false
}

fn test_is_binary_returns_true_for_elf() {
	path := os.join_path(os.temp_dir(), 'test_elf')
	os.write_file_array(path, [u8(0x7f), 0x45, 0x4c, 0x46, 0x02, 0x01, 0x01, 0x00])!
	defer {
		os.rm(path) or {}
	}
	assert is_binary(path) == true
}

fn test_is_binary_returns_true_for_png() {
	path := os.join_path(os.temp_dir(), 'test_image.png')
	os.write_file_array(path, [u8(0x89), 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])!
	defer {
		os.rm(path) or {}
	}
	assert is_binary(path) == true
}

fn test_is_binary_returns_true_for_jpeg() {
	path := os.join_path(os.temp_dir(), 'test_image.jpg')
	os.write_file_array(path, [u8(0xff), 0xd8, 0xff, 0xe0])!
	defer {
		os.rm(path) or {}
	}
	assert is_binary(path) == true
}

fn test_is_binary_returns_true_for_zip() {
	path := os.join_path(os.temp_dir(), 'test_archive.zip')
	os.write_file_array(path, [u8(0x50), 0x4b, 0x03, 0x04])!
	defer {
		os.rm(path) or {}
	}
	assert is_binary(path) == true
}

fn test_is_binary_returns_true_for_pdf() {
	path := os.join_path(os.temp_dir(), 'test_doc.pdf')
	os.write_file(path, '%PDF-1.4 ...')!
	defer {
		os.rm(path) or {}
	}
	assert is_binary(path) == true
}

fn test_is_binary_returns_true_for_gzip() {
	path := os.join_path(os.temp_dir(), 'test_archive.gz')
	os.write_file_array(path, [u8(0x1f), 0x8b, 0x08, 0x00])!
	defer {
		os.rm(path) or {}
	}
	assert is_binary(path) == true
}

fn test_is_binary_returns_true_for_wasm() {
	path := os.join_path(os.temp_dir(), 'test_module.wasm')
	os.write_file_array(path, [u8(0x00), 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00])!
	defer {
		os.rm(path) or {}
	}
	assert is_binary(path) == true
}

fn test_is_binary_returns_false_for_nonexistent_file() {
	assert is_binary('/tmp/this_file_does_not_exist_at_all') == false
}

fn test_is_binary_returns_false_for_v_source() {
	path := os.join_path(os.temp_dir(), 'test_source.v')
	os.write_file(path, 'module main\n\nfn main() {\n\tprintln("hello")\n}\n')!
	defer {
		os.rm(path) or {}
	}
	assert is_binary(path) == false
}

fn test_is_binary_returns_true_for_sqlite() {
	path := os.join_path(os.temp_dir(), 'test_db.sqlite')
	os.write_file(path, 'SQLite format 3\x00')!
	defer {
		os.rm(path) or {}
	}
	assert is_binary(path) == true
}
