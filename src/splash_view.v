// Copyright 2023 The Lilly Editor contributors
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

module main

import math
import term { strikethrough }
import lib.draw

const logo_contents  = $embed_file("./src/splash-logo.txt")

struct Logo{
mut:
	data  []string
	width int
}

struct SplashScreen {
	commit_hash string
pub:
	file_path   string
mut:
	logo        Logo
	leader_mode bool
	f_count     int
	leader_key  string
}

pub fn new_splash(commit_hash string, leader_key string) Viewable {
	assert commit_hash.len > 0
	assert leader_key.len == 1

	mut splash := SplashScreen{
		commit_hash: commit_hash
		file_path: "**lss**"
		logo: Logo{
			data: logo_contents.to_string().split_into_lines()
		}
		leader_key: leader_key
	}

	for l in splash.logo.data {
		assert l.len >= 1
		if l.len > splash.logo.width { splash.logo.width = l.len }
	}

	return splash
}

pub fn (splash SplashScreen) draw(mut ctx draw.Contextable) {
	offset_x := 1
	mut offset_y := 1 + f64(ctx.window_height()) * 0.1
	assert offset_y > 1
	ctx.set_color(r: 245, g: 191, b: 243)
	for i, l in splash.logo.data {
		start_x := offset_x+(ctx.window_width() / 2) - (l.runes().len / 2)
		assert start_x > 2
		if has_colouring_directives(l) {
			for j, c in l.runes() {
				mut to_draw := "${c}"
				if to_draw == "g" { to_draw = " "; ctx.set_color(r: 97, g: 242, b: 136) }
				if to_draw == "p" { to_draw = " "; ctx.set_color(r: 245, g: 191, b: 243) }
				ctx.draw_text(start_x + j, int(math.floor(offset_y))+i, to_draw)
			}
			continue
		}
		ctx.draw_text(offset_x+(ctx.window_width() / 2) - (l.runes().len / 2), int(math.floor(offset_y))+i, l)
	}
	ctx.reset_color()

	offset_y += splash.logo.data.len
	offset_y += (ctx.window_height() - offset_y) * 0.05

	version_label := "lilly - dev version (#${splash.commit_hash})"
	// version_label := "lilly - dev version (#${gitcommit_hash})"
	ctx.draw_text(offset_x+(ctx.window_width() / 2) - (version_label.len / 2), int(math.floor(offset_y)), version_label)

	offset_y += 2

	basic_command_help := [
		" Find File                   <leader>ff",
	]

	disabled_command_help := [
		" Find Word                   <leader>fg",
		" Recent Files                <leader>fo",
		" File Browser                <leader>fv",
		" Colorschemes                <leader>cs",
		" New File                    <leader>nf",
	]

	for h in basic_command_help {
		ctx.draw_text(offset_x+(ctx.window_width() / 2) - (h.len / 2), int(math.floor(offset_y)), h)
		offset_y += 2
	}

	for dh in disabled_command_help {
		ctx.draw_text(offset_x+(ctx.window_width() / 2) - (dh.len / 2), int(math.floor(offset_y)), strikethrough(dh))
		offset_y += 2
	}

	exit_label_str := "Exit/Quit                      ESC"
	ctx.draw_text(offset_x+(ctx.window_width() / 2) - (exit_label_str.len / 2), int(math.floor(offset_y)), exit_label_str)
	offset_y += 2

	copyright_footer := "the lilly editor authors ©"
	ctx.draw_text(offset_x+(ctx.window_width() / 2) - (copyright_footer.len / 2), int(math.floor(offset_y)), copyright_footer)
}

fn has_colouring_directives(line string) bool {
	for c in line.split("") {
		if c == "g" || c == "p" { return true }
	}
	return false
}

pub fn (mut splash SplashScreen) on_key_down(e draw.Event, mut root Root) {
	match e.utf8 {
		splash.leader_key { splash.leader_mode = true }
		else { }
	}
	match e.code {
		.escape    { if splash.leader_mode { splash.leader_mode = false; return } root.quit() }
		// leader_key { splash.leader_mode = true }
		// TODO(tauraamui): move to f() method, this line is a too complicated/long statement now
		.f         { if splash.leader_mode { splash.f_count += 1 } if splash.f_count == 2 { splash.leader_mode = false; splash.f_count = 0; root.open_file_finder() } }
		else { }
	}
}

