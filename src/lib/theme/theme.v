module theme

import term.ui as tui
import lib.syntax as syntaxlib

const colors := $if test { test_colors } $else { non_test_colors }

const non_test_colors := {
	syntaxlib.TokenType.identifier: tui.Color{ 200, 200, 235 }
	.operator:            tui.Color{ 200, 200, 235 }
	.string:              tui.Color{ 87,  215, 217 }
	.comment:             tui.Color{ 130, 130, 130 }
	.comment_start:       tui.Color{ 200, 200, 235 }
	.comment_end:         tui.Color{ 200, 200, 235 }
	.block_start:         tui.Color{ 200, 200, 235 }
	.block_end:           tui.Color{ 200, 200, 235 }
	.number:              tui.Color{ 215, 135, 215 }
	.whitespace:          tui.Color{ 200, 200, 235 }
	.keyword:             tui.Color{ 255, 95,  175 }
	.literal:             tui.Color{ 0,   215, 255 }
	.builtin:             tui.Color{ 130, 144, 250 }
	.other:               tui.Color{ 200, 200, 235 }
}

// NOTE(tauraamui) [10/06/2025]: these colors don't need to be valid at all they're only
//                               here to ensure that colour lookups in tests provide
//                               unique results
const test_colors := {
	syntaxlib.TokenType.identifier: tui.Color{ 999, 999, 999 }
	.operator:            tui.Color{ 987, 987, 987 }
	.string:              tui.Color{ 950, 950, 950 }
	.comment:             tui.Color{ 943, 943, 943 }
	.comment_start:       tui.Color{ 932, 932, 932 }
	.comment_end:         tui.Color{ 920, 920, 920 }
	.block_start:         tui.Color{ 919, 919, 919 }
	.block_end:           tui.Color{ 915, 915, 915 }
	.number:              tui.Color{ 909, 909, 909 }
	.whitespace:          tui.Color{ 875, 445, 789 }
	.keyword:             tui.Color{ 585, 321, 555 }
	.literal:             tui.Color{ 289, 287, 285 }
	.builtin:             tui.Color{ 543, 598, 555 }
	.other:               tui.Color{ 874, 333, 401 }
}

pub fn color_to_type(color tui.Color) ?syntaxlib.TokenType {
	index := colors.values().index(color)
	if index < 0 { return none }
	return colors.keys()[index]
}

pub type Pallete = map[syntaxlib.TokenType]tui.Color

pub struct Theme {
pub:
	pallete           Pallete
	cursor_line_color tui.Color
	background_color  tui.Color
}

pub fn Theme.new(name string) Theme {
	return match name {
		"petal" { Theme{
				pallete: colors,
				cursor_line_color: tui.Color{ 53, 53, 53 },
				background_color: tui.Color{ 59, 34, 76 }
			}
		}
		else { Theme{} }
	}
}

