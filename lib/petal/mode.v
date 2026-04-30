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

module petal

import bobatea as tea
import lib.petal.theme

pub enum Mode as u8 {
	normal
	leader
	command
	insert
	visual
	visual_line
	navigation
}

pub fn (m Mode) color(ttheme theme.Theme) tea.Color {
	return match m {
		.normal { ttheme.status_green }
		.leader { ttheme.status_purple }
		.command { ttheme.status_cyan }
		.insert { ttheme.status_orange }
		.visual { ttheme.status_lilac }
		.visual_line { ttheme.status_lilac }
		.navigation { ttheme.status_cyan }
	}
}

pub fn (m Mode) str() string {
	return match m {
		.normal { 'NORMAL' }
		.leader { 'LEADER' }
		.command { 'COMMAND' }
		.insert { 'INSERT' }
		.visual { 'VISUAL' }
		.visual_line { 'VISUAL LINE' }
		.navigation { 'NAVIGATION' }
	}
}
