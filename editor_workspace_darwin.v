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

fn read_git_branch_from_head_file() string {
	mut dir := os.getwd()
	for {
		head_path := os.join_path(dir, '.git', 'HEAD')
		if os.exists(head_path) {
			content := os.read_file(head_path) or { return '' }
			trimmed := content.trim_space()
			if trimmed.starts_with('ref: refs/heads/') {
				return trimmed.all_after('ref: refs/heads/')
			}
			if trimmed.len >= 7 {
				return trimmed[..7]
			}
			return trimmed
		}
		parent := os.dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return ''
}
