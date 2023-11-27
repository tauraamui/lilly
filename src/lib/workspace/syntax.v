module workspace

import os
import json

const builtin_v_syntax = $embed_file("../../syntax/v.syntax").to_string()

pub struct Syntax {
pub:
	name       string
	extensions []string
	keywords   []string
	literals   []string
}

fn (mut workspace Workspace) load_builtin_syntaxes() {
	vsyntax := json.decode(Syntax, builtin_v_syntax) or { panic("builtin syntax file failed to decode: ${err}") }
	workspace.syntaxes << vsyntax
}

fn (mut workspace Workspace) load_syntaxes_from_disk(config_dir fn () !string, dir_walker fn (path string, f fn (string)), read_file fn (path string) !string) ! {
	config_root_dir := config_dir() or { return error("unable to resolve local config root directory") }
	syntax_dir_full_path := os.join_path(config_root_dir, lilly_config_root_dir_name, lilly_syntaxes_dir_name)
	mut syntaxes_ref := &workspace.syntaxes
	dir_walker(syntax_dir_full_path, fn [mut syntaxes_ref, read_file] (file_path string) {
		if !file_path.ends_with(".syntax") { return }
		contents := read_file(file_path) or { panic("${err.msg()}"); "{}" } // TODO(tauraamui): log out to a file here probably
		syn := json.decode(Syntax, contents) or { Syntax{} }
		if file_path.ends_with("v.syntax") { syntaxes_ref[0] = syn; return }
		syntaxes_ref << syn
	})
}

