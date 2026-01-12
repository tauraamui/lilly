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
	highlight_bg_color           tea.Color @[required]
	petal_pink                   tea.Color @[required]
	petal_green                  tea.Color @[required]
	petal_red                    tea.Color @[required]
	subtle_light_grey            tea.Color @[required]
}

const dark_petal_red = tea.Color.ansi(196)

pub const dark_theme = Theme{
	name: "dark"
	bg_color: palette.matte_black_bg_color
	highlight_bg_color: tea.Color.ansi(239)
	petal_pink: tea.Color.ansi(219)
	petal_green: tea.Color.ansi(84)
	petal_red: dark_petal_red
	subtle_light_grey: tea.Color.ansi(241)
}

const light_petal_pink = tea.Color.ansi(200)
const light_petal_green = tea.Color.ansi(76)
const light_subtle_light_grey = tea.Color.ansi(248)

pub const light_theme = Theme{
	name: "light"
	bg_color: tea.Color.ansi(231)
	highlight_bg_color: tea.Color.ansi(239)
	petal_pink: light_petal_pink
	petal_green: light_petal_green
	petal_red: dark_theme.petal_red
	subtle_light_grey: light_subtle_light_grey
}

