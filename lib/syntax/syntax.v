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

import os

pub const noop_syntax = Syntax{}

// Syntax describes a language. The builtin ones are generated from the
// grammars in grammars/, along with their lexers.
pub struct Syntax {
pub:
	name       string
	extensions []string
	// keywords, literals and builtins are the grammar's word lists, which
	// the original editor colours by
	keywords []string
	literals []string
	builtins []string
	// lang selects the generated lexer
	lang Lang
}

pub fn resolve_from_extension(file_path string) !Syntax {
	ext := os.file_ext(file_path)
	if ext.len == 0 {
		return noop_syntax
	}
	for syn in builtin_syntaxes {
		if ext in syn.extensions {
			return syn
		}
	}
	return noop_syntax
}

pub fn load_builtin_syntaxes() []Syntax {
	return builtin_syntaxes
}
