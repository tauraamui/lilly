module palette

import tauraamui.bobatea as tea

pub const theme_bg_color = matte_black_bg_color
pub const matte_black_bg_color = tea.Color{ 20, 20, 20 }

pub const matte_black_fg_color      = tea.Color.ansi(232)
pub const matte_white_fg_color      = tea.Color{ 230, 230, 230 }
pub const bright_off_white_fg_color = tea.Color{ 255, 255, 255 }
pub const bright_red_fg_color       = tea.Color{ 245, 42, 42 }

pub const subtle_text_fg_color = tea.Color.ansi(249)
pub const help_fg_color = tea.Color.ansi(241)
pub const debug_header_color = tea.Color.ansi(69)
pub const selected_highlight_bg_color = tea.Color.ansi(239)

pub const subtle_border_fg_color = petal_pink_color

pub const petal_pink_color = tea.Color{
	r: 245
	g: 191
	b: 243
}

pub const petal_green_color = tea.Color{
	r: 97
	g: 242
	b: 136
}

pub const status_bar_bg_color         = tea.Color.ansi(234)
pub const status_file_name_bg_color   = tea.Color{ 86, 86, 86 }
pub const status_branch_name_bg_color = tea.Color{ 154, 119, 209 }
pub const status_cursor_pos_bg_color  = tea.Color{ 245, 42, 42 }

pub const status_green      = tea.Color{ 145, 237, 145 }
pub const status_orange     = tea.Color{ 237, 207, 123 }
pub const status_lilac      = tea.Color{ 194, 110, 230 }
pub const status_dark_lilac = tea.Color{ 154, 119, 209 }
pub const status_cyan       = tea.Color{ 138, 222, 237 }
pub const status_purple     = tea.Color{ 130, 144, 250 }

