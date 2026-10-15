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

module main

import bobatea as tea
import lib.petal.theme
import lib.syntax

// ScopeColour is a syntax scope's colour in a theme. set is false for a
// scope the theme leaves uncoloured.
struct ScopeColour {
	colour tea.Color
	set    bool
}

// scope_colours resolves every syntax.Scope to its theme colour, indexed by
// the scope's value, so drawing a token is one array lookup.
fn scope_colours(t theme.Theme) []ScopeColour {
	mut out := []ScopeColour{}
	$for scope in syntax.Scope.values {
		out << scope_colour(t, scope.name)
	}
	return out
}

// scope_colour finds the theme field `syntax_<scope>`, falling back to the
// scope's parents: keyword_control tries syntax_keyword_control, then
// syntax_keyword. The fields are matched at compile time, so a new theme
// field colours its scopes with no other change.
fn scope_colour(t theme.Theme, scope_name string) ScopeColour {
	mut name := 'syntax_${scope_name}'
	for {
		$for f in theme.Theme.fields {
			$if f.typ is tea.Color {
				if f.name == name {
					return ScopeColour{
						colour: t.$(f.name)
						set:    true
					}
				}
			}
		}
		if name.count('_') < 2 {
			return ScopeColour{}
		}
		name = name.all_before_last('_')
	}
	return ScopeColour{}
}
