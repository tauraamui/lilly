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

// syntaxgen generates lib/syntax's lexers from the grammars in
// lib/syntax/grammars, the way tree-sitter generates parser.c: the output is
// plain V, committed alongside the grammars.
//
//   v run cmd/syntaxgen            regenerate lib/syntax/lexer_*.v
//   v run cmd/syntaxgen --check    fail if they are out of date
module main

import os

const grammars_dir = 'lib/syntax/grammars'
const out_dir = 'lib/syntax'
const registry_file = 'lexers.v'
const matchers_file = 'lexer_matchers.v'
const scope_file = 'lib/syntax/scope.v'

fn main() {
	check := '--check' in os.args
	if !os.is_dir(grammars_dir) {
		eprintln('syntaxgen: run from the repository root, ${grammars_dir} not found')
		exit(1)
	}
	target := if check {
		os.join_path(os.temp_dir(), 'lilly-syntaxgen-${os.getpid()}')
	} else {
		out_dir
	}
	os.mkdir_all(target) or { fail(err) }
	written := generate_all(target) or { fail(err) }
	formatted := os.execute('${os.quoted_path(@VEXE)} fmt -w ${written.map(os.quoted_path(it)).join(' ')}')
	if formatted.exit_code != 0 {
		fail(error('v fmt failed on the generated code:\n${formatted.output}'))
	}
	if !check {
		println('syntaxgen: wrote ${written.len} files to ${out_dir}')
		return
	}
	mut stale := []string{}
	for path in written {
		committed := os.join_path(out_dir, os.file_name(path))
		want := os.read_file(path) or { fail(err) }
		have := os.read_file(committed) or { '' }
		if want != have {
			stale << committed
		}
	}
	expected := written.map(os.file_name(it))
	for path in os.glob(os.join_path(out_dir, 'lexer_*.v')) or { []string{} } {
		if os.file_name(path) !in expected {
			stale << '${path} (no grammar generates it)'
		}
	}
	os.rmdir_all(target) or {}
	if stale.len > 0 {
		eprintln('syntaxgen: generated lexers are out of date, run `v run cmd/syntaxgen`:')
		for s in stale {
			eprintln('  ${s}')
		}
		exit(1)
	}
	println('syntaxgen: generated lexers are up to date')
}

// generate_all writes every grammar's lexer and the registry into `dir`,
// returning the paths written
fn generate_all(dir string) ![]string {
	license := os.read_file(os.join_path(grammars_dir, 'LICENSE_HEADER.txt'))!
	mut paths := os.glob(os.join_path(grammars_dir, '*.kdl'))!
	paths.sort()
	scopes := read_scopes(os.read_file(scope_file)!) or { return error('${scope_file}: ${err}') }
	mut grammars := []Grammar{}
	for path in paths {
		g := load_grammar(path)!
		g.check_scopes(scopes) or { return error('${path}: ${err}') }
		grammars << g
	}
	for i in 0 .. grammars.len {
		grammars[i].link_embeds(grammars) or {
			return error('${grammars_dir}/${grammars[i].id}.kdl: ${err}')
		}
	}
	// a grammar that embeds others is generated after them, as it calls
	// their context functions
	mut order := []int{}
	for embeds in [false, true] {
		for i, g in grammars {
			if (g.embeds.len > 0) == embeds {
				order << i
			}
		}
	}
	mut context_emit := map[string][]bool{}
	mut takes_emit := []bool{len: grammars.len}
	mut written := []string{}
	mut matchers := map[string]string{}
	for i in order {
		g := grammars[i]
		generated := generate(g, license, context_emit) or {
			return error('${grammars_dir}/${g.id}.kdl: ${err}')
		}
		out := os.join_path(dir, 'lexer_${g.id}.v')
		os.write_file(out, generated.code)!
		written << out
		context_emit[g.id] = generated.context_emit
		takes_emit[i] = generated.takes_emit
		for name, f in generated.matchers {
			if have := matchers[name] {
				if have != f {
					return error('two pattern matchers hash to ${name}, change how pattern_fn names them')
				}
			}
			matchers[name] = f
		}
	}
	shared := os.join_path(dir, matchers_file)
	os.write_file(shared, generate_matchers(matchers, license))!
	written << shared
	registry := os.join_path(dir, registry_file)
	os.write_file(registry, generate_registry(grammars, takes_emit, license))!
	written << registry
	return written
}

@[noreturn]
fn fail(err IError) {
	eprintln('syntaxgen: ${err}')
	exit(1)
}
