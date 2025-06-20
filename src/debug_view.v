// Copyright 2024 The Lilly Editor contributors
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

import lib.draw

struct Debug {
	file_path string
}

const font_size = 16

fn (mut debug Debug) set_from(from int) {}

// It turns out that the TUI renderer actually considers 0 + 1 to be the same thing.
// So technically we can say that the top left first possible to render position is 1, 1 instead of 0, 0.
// Ok, for so for GUI rendering of text, or at least the invocation of "draw_text", it also seems to consider
// single incrementations of Y as being a full char height span.
fn (mut debug Debug) draw(mut ctx draw.Contextable) {
	for j in 0 .. ctx.window_height() {
		for i in 0 .. 10 {
			ctx.draw_text((font_size / 2) + i, j, '${i}')
		}
	}
}

fn (mut debug Debug) on_key_down(e draw.Event, mut r Root) {
	if e.code == .escape {
		r.quit() or {}
	}
}

fn (mut debug Debug) on_mouse_scroll(e draw.Event) {}
