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

import lib.draw

enum Mode as u8 {
	normal
	visual
	visual_line
	insert
	command
	search
	leader
	pending_delete
	replace
}

fn (mode Mode) draw(mut ctx draw.Contextable, x int, y int) int {
	defer { ctx.reset() }
	label := mode.str()
	status_line_y := y
	status_line_x := x
	status_color := mode.color()
	mut offset := 0
	paint_shape_text(mut ctx, status_line_x + offset, status_line_y, status_color, "${left_rounded}${block}")
	offset += 2
	paint_text_on_background(mut ctx, status_line_x + offset, status_line_y, status_color, Color{ 0, 0, 0}, label)
	offset += label.len
	paint_shape_text(mut ctx, status_line_x + offset, status_line_y, status_color, "${block}${slant_right_flat_bottom}")
	offset += 2
	return status_line_x + offset
}

fn (mode Mode) color() Color {
	return match mode {
		.normal { status_green }
		.visual { status_lilac }
		.visual_line { status_lilac }
		.insert { status_orange }
		.command { status_cyan }
		.search { status_purple }
		.leader { status_purple }
		.pending_delete { status_green }
		.replace { status_green }
	}
}

fn (mode Mode) str() string {
	return match mode {
		.normal  { "NORMAL"  }
		.visual  { "VISUAL"  }
		.visual_line { "VISUAL LINE"  }
		.insert  { "INSERT"  }
		.command { "COMMAND" }
		.search  { "SEARCH"  }
		.leader  { "LEADER" }
		.pending_delete { "NORMAL" }
		.replace { "NORMAL" }
	}
}

