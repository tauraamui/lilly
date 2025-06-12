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

const builtin_v_syntax = $embed_file('../../syntax/v.syntax').to_string()
const builtin_go_syntax = $embed_file('../../syntax/go.syntax').to_string()
const builtin_c_syntax = $embed_file('../../syntax/c.syntax').to_string()
const builtin_rust_syntax = $embed_file('../../syntax/rust.syntax').to_string()
const builtin_js_syntax = $embed_file('../../syntax/javascript.syntax').to_string()
const builtin_ts_syntax = $embed_file('../../syntax/typescript.syntax').to_string()
const builtin_python_syntax = $embed_file('../../syntax/python.syntax').to_string()
const builtin_perl_syntax = $embed_file('../../syntax/perl.syntax').to_string()

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

