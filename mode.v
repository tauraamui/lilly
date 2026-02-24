module petal

import tauraamui.bobatea as tea
import theme

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
