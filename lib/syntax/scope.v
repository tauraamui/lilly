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

module syntax

// Scope is what a token is, as far as colouring goes. Grammars name scopes
// with dots (`keyword.control`), which map onto these names with underscores.
// Each name after the first underscore narrows the one before it, so a theme
// that has no colour for `keyword_control` falls back to `keyword`.
pub enum Scope as u8 {
	none
	comment
	comment_doc
	string
	string_escape
	number
	literal
	keyword
	keyword_control
	keyword_directive
	keyword_operator
	builtin
	storage_type
	storage_type_builtin
	// storage_type_definition is a type's name where it's defined
	storage_type_definition
	function
	function_macro
	// function_definition is a function's name where it's defined, where
	// `function` alone is a call
	function_definition
	variable
	variable_special
	// variable_definition is a variable's name where it's declared
	variable_definition
	attribute
	label
	operator
	punctuation
}
