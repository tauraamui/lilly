module theme

import tauraamui.bobatea as tea
import palette

pub const dark_theme_name  = "dark"
pub const light_theme_name = "light"

pub struct Theme {
pub:
	name                         string    @[required]
	bg_color                     tea.Color @[required]
	fg_color                     tea.Color

	active_split_divider_color   tea.Color @[required]
	inactive_split_divider_color tea.Color @[required]

	petal_pink                   tea.Color
	petal_green                  tea.Color
}

pub const dark_theme = Theme{
	name: "dark"
	bg_color: palette.matte_black_bg_color

	active_split_divider_color: palette.petal_pink_color
	inactive_split_divider_color: palette.status_bar_bg_color

	petal_pink: tea.Color.ansi(219)
	petal_green: tea.Color.ansi(84)
}

pub const light_theme = Theme{
	name: "light"
	bg_color: palette.matte_white_fg_color

	active_split_divider_color: palette.petal_pink_color
	inactive_split_divider_color: palette.status_bar_bg_color

	petal_pink: tea.Color.ansi(206)
	petal_green: tea.Color.ansi(76)
}

