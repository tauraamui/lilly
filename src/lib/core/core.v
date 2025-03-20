// Copyright 2025 Google LLC
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

module core

import os

pub fn is_binary_file(path string) bool {
	mut f := os.open(path) or { return true }
	mut buf := []u8{ len: 1024 }
	bytes_read := f.read_bytes_into(0, mut buf) or { return true }

	mut non_text_bytes := 0
	for i in 0..bytes_read {
		b := buf[i]
		// count bytes outside printable ASCII range
		if (b < 32 && b != 9 && b != 10 && b != 13) || b > 126 {
			non_text_bytes += 1
		}
	}

	// if more than 30% of read bytes are non-text, consider it to be a binary file
	return (f64(non_text_bytes) / f64(bytes_read)) > 0.3
}

