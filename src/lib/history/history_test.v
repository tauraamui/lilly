// Copyright 2024 The Lilly Editor contributors
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

module history

import lib.diff { Op }

fn test_generate_diff_ops_twixt_two_file_versions() {
	fake_file_1 := [
		'1. first existing line',
	]

	fake_file_2 := [
		'1. first existing line',
		'2. second new line which was added',
	]

	mut his := History{}
	his.append_ops_to_undo(fake_file_1, fake_file_2)

	assert his.undos.array() == [
		Op{
			line_num: 0
			value:    '2. second new line which was added'
			kind:     'ins'
		},
	]
}
