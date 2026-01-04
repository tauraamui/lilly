module palette

import tauraamui.bobatea as tea

fn test_fg_color_from_shades_of_bg() {
	assert fg_color(tea.Color{ 10, 10, 10 })    == matte_white_fg_color
	assert fg_color(tea.Color{ 200, 200, 200 }) == matte_black_fg_color
}

