// Copyright 2025 The Lilly Editor contributors
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

module ui

import lib.buffer
import lib.draw
import lib.syntax
import lib.utf8

pub struct BufferView {
	buf       &buffer.Buffer = unsafe { nil }
	syntaxes  []syntax.Syntax
	syntax_id int
mut:
	parser   syntax.Parser
}

pub fn BufferView.new(buf &buffer.Buffer, syntaxes []syntax.Syntax, syntax_id int) BufferView {
	return BufferView{
		buf: buf
		syntaxes: syntaxes
		syntax_id: syntax_id
		parser: syntax.Parser.new(syntaxes)
	}
}

pub fn (mut buf_view BufferView) draw(
	mut ctx draw.Contextable,
	x int, y int,
	width int, height int,
	from_line_num int,
	min_x int,
	cursor_y_pos int,
	relative_line_nums bool
) {
	if buf_view.buf == unsafe { nil } { return }
	syntax_def := buf_view.syntaxes[buf_view.syntax_id] or { syntax.Syntax{} }

	mut screenspace_x_offset := buf_view.buf.num_of_lines().str().runes().len
	mut screenspace_y_offset := 0

	buf_view.parser.reset()
	mut syntax_parser := buf_view.parser

	for document_line_num, line in buf_view.buf.line_iterator() {
		syntax_parser.parse_line(document_line_num, line)
		// if we haven't reached the line to render in the document yet, skip this
		if document_line_num < from_line_num { continue }

		// draw line number
		draw_line_number(
			mut ctx, x, y,
			screenspace_x_offset, screenspace_y_offset,
			document_line_num, cursor_y_pos, relative_line_nums
		)

		is_cursor_line := document_line_num == cursor_y_pos
		if is_cursor_line {
			ctx.set_bg_color(draw.Color{53, 53, 53})
			ctx.draw_rect(x + screenspace_x_offset + 1, y + screenspace_y_offset, width - (x + screenspace_x_offset), 1)
			ctx.reset_bg_color()
		}
		// draw the line of text, offset by the position of the buffer view
		draw_text_line(
			mut ctx,
			x + screenspace_x_offset + 1,
			y + screenspace_y_offset,
			line,
			syntax_parser.get_line_tokens(document_line_num),
			syntax_def,
			min_x,
			width,
			is_cursor_line
		)

		screenspace_y_offset += 1
		// detect if number of lines drawn would exceed current height of view
		if screenspace_y_offset > height { return }
	}
}

const line_num_fg_color = draw.Color{ r: 117, g: 118, b: 120 }

fn draw_line_number(
	mut ctx draw.Contextable,
	x int, y int,
	screenspace_x_offset int, screenspace_y_offset int,
	document_line_num int, cursor_y_pos int, relative_line_nums bool
) {
	defer { ctx.reset_color() }
	ctx.set_color(line_num_fg_color)

	// line_num_str := "${document_line_num + 1}"
	line_num_str := match relative_line_nums {
		true {
			match document_line_num == cursor_y_pos {
				true { "${document_line_num + 1}" }
				else { "x" }
			}
		}
		else {
			"${document_line_num + 1}"
		}
	}

	xx := x + screenspace_x_offset
	yy := y + screenspace_y_offset
	ctx.draw_text(xx - line_num_str.runes().len, yy, line_num_str)
}

/*
fn (mut view View) draw_text_line_number(mut ctx draw.Contextable, y int) {
	cursor_screenspace_y := view.cursor.pos.y - view.from
	ctx.set_color(r: 117, g: 118, b: 120)

	mut line_num_str := '${view.from + y + 1}'
	if view.config.relative_line_numbers {
		if y < cursor_screenspace_y {
			line_num_str = '${cursor_screenspace_y - y}'
		} else if cursor_screenspace_y == y {
			line_num_str = '${view.from + y + 1}'
		} else if y > cursor_screenspace_y {
			line_num_str = '${y - cursor_screenspace_y}'
		}
	}
	ctx.draw_text(view.x - line_num_str.runes().len - 1, y, line_num_str)
	ctx.reset_color()
}
*/

fn draw_text_line(
	mut ctx draw.Contextable,
	x int, y int,
	line string,
	line_tokens []syntax.Token,
	syntax_def syntax.Syntax,
	min_x int, width int,
	is_cursor_line bool
) {
	max_width := width - x
	if is_cursor_line {
		ctx.set_bg_color(draw.Color{53, 53, 53})
		defer { ctx.reset_bg_color() }
	}

	mut visual_x_offset := x
	mut previous_token := ?syntax.Token(none)
	for i, token in line_tokens {
		current_token := token
		mut next_token := ?syntax.Token(none)
		if i + 1 < line_tokens.len - 1 { next_token = line_tokens[i + 1] }
		cur_token_bounds := resolve_token_bounds(current_token.start(), current_token.end(), min_x) or { continue }
		cur_token_type := current_token.t_type()
		visual_x_offset += render_token(
			mut ctx, line,
			cur_token_bounds, previous_token,
			current_token, next_token, syntax_def,
			min_x, x, max_width,
			visual_x_offset, y
		)
		if cur_token_type != .whitespace {
			previous_token = current_token
		}
	}
}

struct TokenBounds {
	start int
	end   int
}

fn resolve_token_bounds(token_start int, token_end int, min_x int) ?TokenBounds {
	if token_end < token_start { return none }
	if token_end < min_x { return none }
	if token_end > min_x && token_start < min_x {
		return TokenBounds{ start: min_x, end: token_end }
	}
	return TokenBounds{ start: token_start, end: token_end }
}

fn render_token(
	mut ctx draw.Contextable,
	line string, cur_token_bounds TokenBounds,
	previous_token ?syntax.Token,
	current_token syntax.Token,
	next_token ?syntax.Token,
	syntax_def syntax.Syntax,
	min_x int, base_x int,
	max_width int, x_offset int, y int
) int {
	mut segment_to_render := line.runes()[cur_token_bounds.start..cur_token_bounds.end].string().replace("\t", " ".repeat(4))
	segment_to_render = utf8.str_clamp_to_visible_length(segment_to_render, max_width - (x_offset - base_x))
	if segment_to_render.runes().len == 0 { return 0 }

	cur_token_type := current_token.t_type()
	resolved_token_type := match true {
		cur_token_type        == .comment { cur_token_type }
		segment_to_render in syntax_def.literals { syntax.TokenType.literal }
		segment_to_render in syntax_def.keywords { syntax.TokenType.keyword }
		segment_to_render in syntax_def.builtins { syntax.TokenType.builtin }
		else { cur_token_type }
	}

	ctx.set_color(syntax.colors[resolved_token_type])
	ctx.draw_text(x_offset, y, segment_to_render)
	return utf8_str_visible_length(segment_to_render)
}

