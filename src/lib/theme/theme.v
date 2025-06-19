module theme

import term.ui as tui
import lib.syntax as syntaxlib

const acme_pallete := {
	syntaxlib.TokenType.identifier: tui.Color{ 15, 12, 0 }
	.operator:            tui.Color{ 15, 12, 0 }
	.string:              tui.Color{ 146, 100, 25 }
	.comment:             tui.Color{ 22, 78, 15 }
	.comment_start:       tui.Color{ 22, 78, 15 }
	.comment_end:         tui.Color{ 22, 78, 15 }
	.block_start:         tui.Color{ 15, 12, 0 }
	.block_end:           tui.Color{ 15, 12, 0 }
	.number:              tui.Color{ 15, 12, 0 }
	.whitespace:          tui.Color{ 15, 12, 0 }
	.keyword:             tui.Color{ 0, 200, 215 }
	.literal:             tui.Color{ 15, 12, 0 }
	.builtin:             tui.Color{ 15, 12, 0 }
	.other:               tui.Color{ 15, 12, 0 }
}

const black_astra_pallete := {
	syntaxlib.TokenType.identifier: tui.Color{ 255, 255, 255 }
	.operator:            tui.Color{ 15, 12, 0 }
	.string:              tui.Color{ 255, 95, 135 }
	.comment:             tui.Color{ 192, 192, 192 }
	.comment_start:       tui.Color{ 192, 192, 192 }
	.comment_end:         tui.Color{ 192, 192, 192 }
	.block_start:         tui.Color{ 15, 12, 0 }
	.block_end:           tui.Color{ 15, 12, 0 }
	.number:              tui.Color{ 255, 0, 175 }
	.whitespace:          tui.Color{ 15, 12, 0 }
	.keyword:             tui.Color{ 255, 0, 95 }
	.literal:             tui.Color{ 255, 135, 0 }
	.builtin:             tui.Color{ 255, 255, 255 }
	.other:               tui.Color{ 255, 255, 255 }
}

const bloo_pallete := {
	syntaxlib.TokenType.identifier: tui.Color{ 255, 255, 255 }
	.operator:            tui.Color{ 15, 12, 0 }
	.string:              tui.Color{ 175, 255, 255 }
	.comment:             tui.Color{ 192, 192, 192 }
	.comment_start:       tui.Color{ 192, 192, 192 }
	.comment_end:         tui.Color{ 192, 192, 192 }
	.block_start:         tui.Color{ 15, 12, 0 }
	.block_end:           tui.Color{ 15, 12, 0 }
	.number:              tui.Color{ 175, 215, 255 }
	.whitespace:          tui.Color{ 15, 12, 0 }
	.keyword:             tui.Color{ 0, 255, 255 }
	.literal:             tui.Color{ 255, 255, 255 }
	.builtin:             tui.Color{ 255, 255, 255 }
	.other:               tui.Color{ 255, 255, 255 }
}

const petal_pallete := {
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
const test_pallete := {
	syntaxlib.TokenType.identifier: tui.Color{ 99, 99, 99 }
	.operator:            tui.Color{ 87, 87, 87 }
	.string:              tui.Color{ 50, 50, 50 }
	.comment:             tui.Color{ 43, 43, 43 }
	.comment_start:       tui.Color{ 32, 32, 32 }
	.comment_end:         tui.Color{ 20, 20, 20 }
	.block_start:         tui.Color{ 19, 19, 19 }
	.block_end:           tui.Color{ 15, 15, 15 }
	.number:              tui.Color{ 49, 49, 49 }
	.whitespace:          tui.Color{ 75, 45, 79 }
	.keyword:             tui.Color{ 5, 21, 5 }
	.literal:             tui.Color{ 15, 15, 15 }
	.builtin:             tui.Color{ 102, 102, 102 }
	.other:               tui.Color{ 215, 0, 0 }
}

pub fn color_to_type(color tui.Color) ?syntaxlib.TokenType {
	index := test_pallete.values().index(color)
	if index < 0 { return none }
	return test_pallete.keys()[index]
}

pub type Pallete = map[syntaxlib.TokenType]tui.Color

pub struct Theme {
pub:
	pallete                   Pallete
	cursor_line_color         tui.Color
	selection_highlight_color tui.Color
	background_color          ?tui.Color
	line_number_color         tui.Color
}

pub fn Theme.new(name string) !Theme {
	$if test {
		return Theme{
			pallete: test_pallete,
			cursor_line_color: tui.Color{ 53, 53, 53 },
			selection_highlight_color: tui.Color{ 111, 111, 111 },
			background_color: tui.Color{ 59, 34, 76 },
			line_number_color: test_pallete[.number]
		}
	}
	return match name {
		"acme" {
			Theme{
				pallete: acme_pallete,
				cursor_line_color: tui.Color{ 174, 255, 254 },
				selection_highlight_color: tui.Color{ 96, 138, 143 },
				background_color: tui.Color{ 255, 255, 215 },
				line_number_color: acme_pallete[.number]
			}
		}
		"bloo" { // boris johnson reference. "I like to paint them .. BLOO!" (if you know you know)
			Theme{
				pallete: bloo_pallete,
				cursor_line_color: tui.Color{ 0, 0, 175 },
				selection_highlight_color: tui.Color{ 96, 138, 143 },
				background_color: tui.Color{ 0, 95, 255 },
				line_number_color: bloo_pallete[.number]
			}
		}
		"petal" {
			Theme{
				pallete: petal_pallete,
				cursor_line_color: tui.Color{ 53, 53, 53 },
				selection_highlight_color: tui.Color{ 96, 138, 143 },
				background_color: tui.Color{ 59, 34, 76 },
				line_number_color: petal_pallete[.number]
			}
		}
		"black-astra" { // black clover reference
			Theme{
				pallete: black_astra_pallete,
				cursor_line_color: tui.Color{ 53, 53, 53 },
				selection_highlight_color: tui.Color{ 135, 0, 175 },
				background_color: tui.Color{ 20, 20, 20 },
				line_number_color: tui.Color{ 175, 0, 0 }
			}
		}
		"space" {
			Theme{
				pallete: petal_pallete,
				cursor_line_color: tui.Color{ 53, 53, 53 },
				selection_highlight_color: tui.Color{ 96, 138, 143 },
				line_number_color: petal_pallete[.number]
			}
		}
		else { error("unable to find theme '${name}'") }
	}
}

