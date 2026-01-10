module main

import tauraamui.bobatea as tea
import palette

enum Mode as u8 {
	normal
	leader
	command
	insert
	visual
	visual_line
	navigation
}

fn (m Mode) color() tea.Color {
	return match m {
		.normal { palette.status_green }
		.leader { palette.status_purple }
		.command { palette.status_cyan }
		.insert { palette.status_orange }
		.visual { palette.status_lilac }
		.visual_line { palette.status_lilac }
		.navigation { palette.status_cyan }
	}
}

fn (m Mode) str() string {
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
