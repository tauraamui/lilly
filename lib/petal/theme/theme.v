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

module theme

import bobatea as tea

pub const dark_theme_name = 'dark'
pub const light_theme_name = 'light'

pub struct Theme {
pub:
	name               string    @[required]
	bg_color           tea.Color @[required]
	fg_color           tea.Color
	highlight_bg_color tea.Color @[required]
	petal_pink         tea.Color @[required]
	petal_green        tea.Color @[required]
	petal_red          tea.Color @[required]
	subtle_light_grey  tea.Color @[required]

	status_file_name   tea.Color @[required]
	status_branch_name tea.Color @[required]
	status_bar_spacer  tea.Color @[required]

	status_green  tea.Color @[required]
	status_purple tea.Color @[required]
	status_cyan   tea.Color @[required]
	status_orange tea.Color @[required]
	status_lilac  tea.Color @[required]

	syntax_comment tea.Color @[required]
	syntax_string  tea.Color @[required]
	syntax_literal tea.Color @[required]
	syntax_builtin tea.Color @[required]

	cursor_line_bg tea.Color @[required]
}

const dark_petal_pink = tea.Color.ansi(219)
const dark_petal_red = tea.Color.ansi(196)

pub const dark_theme = Theme{
	name:               'dark'
	bg_color:           tea.Color.ansi(233)
	highlight_bg_color: tea.Color.ansi(139)
	petal_pink:         dark_petal_pink
	petal_green:        tea.Color.ansi(84)
	petal_red:          dark_petal_red
	subtle_light_grey:  tea.Color.ansi(241)

	status_file_name:   tea.Color.ansi(239)
	status_bar_spacer:  tea.Color.ansi(234)
	status_branch_name: dark_petal_pink

	status_green:  tea.Color.ansi(120)
	status_purple: tea.Color.ansi(105)
	status_cyan:   tea.Color.ansi(117)
	status_orange: tea.Color.ansi(222)
	status_lilac:  tea.Color.ansi(134)

	syntax_comment: tea.Color.ansi(241)
	syntax_string:  dark_petal_pink
	syntax_literal: tea.Color.ansi(84)
	syntax_builtin: dark_petal_red

	cursor_line_bg: tea.Color.ansi(235)
}

const light_petal_pink = tea.Color.ansi(200)
const light_petal_green = tea.Color.ansi(76)
const light_subtle_light_grey = tea.Color.ansi(248)

pub const light_theme = Theme{
	name:               'light'
	bg_color:           tea.Color.ansi(231)
	highlight_bg_color: tea.Color.ansi(218)
	petal_pink:         light_petal_pink
	petal_green:        light_petal_green
	petal_red:          dark_theme.petal_red
	subtle_light_grey:  light_subtle_light_grey

	status_file_name:   tea.Color.ansi(242)
	status_bar_spacer:  tea.Color.ansi(255)
	status_branch_name: tea.Color.ansi(219)

	status_green:  tea.Color.ansi(120)
	status_purple: tea.Color.ansi(105)
	status_cyan:   tea.Color.ansi(117)
	status_orange: tea.Color.ansi(222)
	status_lilac:  tea.Color.ansi(134)

	syntax_comment: light_subtle_light_grey
	syntax_string:  light_petal_pink
	syntax_literal: light_petal_green
	syntax_builtin: dark_theme.petal_red

	cursor_line_bg: tea.Color.ansi(254)
}
