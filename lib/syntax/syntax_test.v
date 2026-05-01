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

const t_lilly_config_root_dir_name = 'lilly'
const t_lilly_syntaxes_dir_name = 'syntaxes'

@[assert_continues]
fn test_resolve_from_extension_returns_noop_syntax_for_unknown_extension() {
	syn := resolve_from_extension('file.unknown_ext') or {
		assert false, 'unexpected error: ${err}'
		return
	}
	assert syn.name == ''
	assert syn.extensions == []
	assert syn.keywords == []
}

@[assert_continues]
fn test_resolve_from_extension_resolves_v_syntax() {
	syn := resolve_from_extension('main.v') or {
		assert false, 'unexpected error: ${err}'
		return
	}
	assert syn.name == 'V'
}

@[assert_continues]
fn test_resolve_from_extension_resolves_go_syntax() {
	syn := resolve_from_extension('main.go') or {
		assert false, 'unexpected error: ${err}'
		return
	}
	assert syn.name == 'Go'
}

@[assert_continues]
fn test_resolve_from_extension_resolves_c_syntax() {
	syn := resolve_from_extension('main.c') or {
		assert false, 'unexpected error: ${err}'
		return
	}
	assert syn.name == 'C'
}

@[assert_continues]
fn test_resolve_from_extension_resolves_rust_syntax() {
	syn := resolve_from_extension('main.rs') or {
		assert false, 'unexpected error: ${err}'
		return
	}
	assert syn.name == 'Rust'
}

@[assert_continues]
fn test_resolve_from_extension_resolves_javascript_syntax() {
	syn := resolve_from_extension('index.js') or {
		assert false, 'unexpected error: ${err}'
		return
	}
	assert syn.name == 'JavaScript'
}

@[assert_continues]
fn test_resolve_from_extension_resolves_typescript_syntax() {
	syn := resolve_from_extension('index.ts') or {
		assert false, 'unexpected error: ${err}'
		return
	}
	assert syn.name == 'TypeScript'
}

@[assert_continues]
fn test_resolve_from_extension_resolves_python_syntax() {
	syn := resolve_from_extension('script.py') or {
		assert false, 'unexpected error: ${err}'
		return
	}
	assert syn.name == 'Python'
}

@[assert_continues]
fn test_resolve_from_extension_resolves_perl_syntax() {
	syn := resolve_from_extension('script.pl') or {
		assert false, 'unexpected error: ${err}'
		return
	}
	assert syn.name == 'Perl'
}

@[assert_continues]
fn test_loads_builtin_syntax() {
	builtins := load_builtin_syntaxes()
	assert builtins.len == 10
	assert builtins[0].name == 'V'
	assert builtins[1].name == 'Go'
	assert builtins[2].name == 'C'
	assert builtins[3].name == 'Rust'
	assert builtins[4].name == 'JavaScript'
	assert builtins[5].name == 'TypeScript'
	assert builtins[6].name == 'Python'
	assert builtins[7].name == 'Perl'
	assert builtins[8].name == 'Zig'
	assert builtins[9].name == 'Gleam'
}

@[assert_continues]
fn test_resolve_from_extension_resolves_zig_syntax() {
	syn := resolve_from_extension('main.zig') or {
		assert false, 'unexpected error: ${err}'
		return
	}
	assert syn.name == 'Zig'
	assert '@' in syn.identifier_chars
	assert '@import' in syn.builtins
}

@[assert_continues]
fn test_resolve_from_extension_resolves_gleam_syntax() {
	syn := resolve_from_extension('main.gleam') or {
		assert false, 'unexpected error: ${err}'
		return
	}
	assert syn.name == 'Gleam'
	assert 'binary' in syn.builtins
}
