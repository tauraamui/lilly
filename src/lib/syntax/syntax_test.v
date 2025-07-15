// Copyright 2025 The Lilly Editor contributors
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

module syntax

import os

const t_lilly_config_root_dir_name = 'lilly'
const t_lilly_syntaxes_dir_name = 'syntaxes'

@[assert_continues]
fn test_loads_builtin_syntax() {
	builtins := load_builtin_syntaxes()
	assert builtins.len == 8
	assert builtins[0].name == 'V'
	assert builtins[1].name == 'Go'
	assert builtins[2].name == 'C'
	assert builtins[3].name == 'Rust'
	assert builtins[4].name == 'JavaScript'
	assert builtins[5].name == 'TypeScript'
	assert builtins[6].name == 'Python'
	assert builtins[7].name == 'Perl'
}
