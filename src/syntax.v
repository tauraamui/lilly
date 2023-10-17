module main

import os
import json

const builtin_v_syntax_file_content = $embed_file('syntax/v.syntax').to_string()

struct Syntax {
	name       string
	extensions []string
	fmt_cmd    string
	keywords   []string
	literals   []string
}

fn (mut view View) load_syntaxes() {
	println('loading syntax files...')
	vsyntax := json.decode(Syntax, builtin_v_syntax_file_content) or {
		panic('the builtin syntax file can not be decoded')
	}
	view.syntaxes << vsyntax
	files := os.walk_ext(syntax_dir, '.syntax')
	for file in files {
		fcontent := os.read_file(file) or {
			eprintln('    error: cannot load syntax file ${file}: ${err.msg()}')
			'{}'
		}
		syntax := json.decode(Syntax, fcontent) or {
			eprintln('    error: cannot load syntax file ${file}: ${err.msg()}')
			Syntax{}
		}
		if file.ends_with('v.syntax') {
			// allow overriding the builtin embedded syntax at runtime:
			view.syntaxes[0] = syntax
			continue
		}
		view.syntaxes << syntax
	}
	println('${files.len} syntax files loaded + the compile time builtin syntax for .v')
}

fn (mut view View) set_current_syntax_idx(ext string) {
	for i, syntax in view.syntaxes {
		if ext in syntax.extensions {
			println('selected syntax ${syntax.name} for extension ${ext}')
			view.current_syntax_idx = i
			break
		}
	}
}
