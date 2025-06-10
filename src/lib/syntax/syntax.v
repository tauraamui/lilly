// Copyright 2025 The Lilly Edtior contributors
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

import json
import lib.draw

const builtin_v_syntax = $embed_file('../../syntax/v.syntax').to_string()
const builtin_go_syntax = $embed_file('../../syntax/go.syntax').to_string()
const builtin_c_syntax = $embed_file('../../syntax/c.syntax').to_string()
const builtin_rust_syntax = $embed_file('../../syntax/rust.syntax').to_string()
const builtin_js_syntax = $embed_file('../../syntax/javascript.syntax').to_string()
const builtin_ts_syntax = $embed_file('../../syntax/typescript.syntax').to_string()
const builtin_python_syntax = $embed_file('../../syntax/python.syntax').to_string()
const builtin_perl_syntax = $embed_file('../../syntax/perl.syntax').to_string()

pub const colors := $if test { test_colors } $else { non_test_colors }

const non_test_colors := {
	TokenType.identifier: draw.Color{ 200, 200, 235 }
	.operator:            draw.Color{ 200, 200, 235 }
	.string:              draw.Color{ 87,  215, 217 }
	.comment:             draw.Color{ 130, 130, 130 }
	.comment_start:       draw.Color{ 200, 200, 235 }
	.comment_end:         draw.Color{ 200, 200, 235 }
	.block_start:         draw.Color{ 200, 200, 235 }
	.block_end:           draw.Color{ 200, 200, 235 }
	.number:              draw.Color{ 215, 135, 215 }
	.whitespace:          draw.Color{ 200, 200, 235 }
	.keyword:             draw.Color{ 255, 95,  175 }
	.literal:             draw.Color{ 0,   215, 255 }
	.builtin:             draw.Color{ 130, 144, 250 }
	.other:               draw.Color{ 200, 200, 235 }
}

// NOTE(tauraamui) [10/06/2025]: these colors don't need to be valid at all they're only
//                               here to ensure that colour lookups in tests provide
//                               unique results
const test_colors := {
	TokenType.identifier: draw.Color{ 999, 999, 999 }
	.operator:            draw.Color{ 987, 987, 987 }
	.string:              draw.Color{ 950, 950, 950 }
	.comment:             draw.Color{ 943, 943, 943 }
	.comment_start:       draw.Color{ 932, 932, 932 }
	.comment_end:         draw.Color{ 920, 920, 920 }
	.block_start:         draw.Color{ 919, 919, 919 }
	.block_end:           draw.Color{ 915, 915, 915 }
	.number:              draw.Color{ 909, 909, 909 }
	.whitespace:          draw.Color{ 875, 445, 789 }
	.keyword:             draw.Color{ 585, 321, 555 }
	.literal:             draw.Color{ 289, 287, 285 }
	.builtin:             draw.Color{ 543, 598, 555 }
	.other:               draw.Color{ 874, 333, 401 }
}

pub fn color_to_type(color draw.Color) ?TokenType {
	index := colors.values().index(color)
	if index < 0 { return none }
	return colors.keys()[index]
}

pub struct Syntax {
pub:
	name       string
	extensions []string
	keywords   []string
	literals   []string
	builtins   []string
}

pub fn load_builtin_syntaxes() []Syntax {
	v_syntax := json.decode(Syntax, builtin_v_syntax) or {
		panic('builtin V syntax file failed to decode: ${err}')
	}
	go_syntax := json.decode(Syntax, builtin_go_syntax) or {
		panic('builtin Go syntax file failed to decode: ${err}')
	}
	c_syntax := json.decode(Syntax, builtin_c_syntax) or {
		panic('builtin C syntax file failed to decode: ${err}')
	}
	rust_syntax := json.decode(Syntax, builtin_rust_syntax) or {
		panic('builtin Rust syntax file failed to decode: ${err}')
	}
	js_syntax := json.decode(Syntax, builtin_js_syntax) or {
		panic('builtin JavaScript syntax file failed to decode: ${err}')
	}
	ts_syntax := json.decode(Syntax, builtin_ts_syntax) or {
		panic('builtin TypeScript syntax file failed to decode: ${err}')
	}
	python_syntax := json.decode(Syntax, builtin_python_syntax) or {
		panic('builtin Python syntax file failed to decode: ${err}')
	}
	perl_syntax := json.decode(Syntax, builtin_perl_syntax) or {
		panic('builting Perl syntax file failed to decode: ${err}')
	}

	return [v_syntax, go_syntax, c_syntax, rust_syntax, js_syntax, ts_syntax, python_syntax, perl_syntax]
}

fn load_syntaxes_from_disk(
	syntax_config_dir fn () !string,
	dir_walker fn (path string, f fn (string)),
	read_file fn (path string) !string
) ![]Syntax {
	syntax_dir_full_path := syntax_config_dir() or { return err }
	mut syns := []Syntax{}
	dir_walker(syntax_dir_full_path, fn [mut syns, read_file] (file_path string) {
		if !file_path.ends_with('.syntax') {
			return
		}
		contents := read_file(file_path) or {
			panic('${err.msg()}')
			'{}'
		} // TODO(tauraamui): log out to a file here probably
		mut syn := json.decode(Syntax, contents) or { Syntax{} }
		if file_path.ends_with('v.syntax') {
			unsafe {
				syns[0] = syn
			}
			return
		}
		if file_path.ends_with('go.syntax') {
			unsafe {
				syns[1] = syn
			}
			return
		}
		if file_path.ends_with('c.syntax') {
			unsafe {
				syns[2] = syn
			}
			return
		}
		if file_path.ends_with('rust.syntax') {
			unsafe {
				syns[3] = syn
			}
			return
		}
		if file_path.ends_with('js.syntax') {
			unsafe {
				syns[4] = syn
			}
			return
		}
		if file_path.ends_with('ts.syntax') {
			unsafe {
				syns[5] = syn
			}
			return
		}
		if file_path.ends_with('python.syntax') {
			unsafe {
				syns[6] = syn
			}
			return
		}
		if file_path.ends_with('perl.syntax') {
			unsafe {
				syns[7] = syn
			}
			return
		}
		syns << syn
	})
	return syns
}

