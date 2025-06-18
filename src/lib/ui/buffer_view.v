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
import term.ui as tui
import lib.syntax
import lib.theme as themelib
import lib.utf8
import lib.core

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
	relative_line_nums bool,
	current_mode core.Mode,
	cursor BufferCursor,
) {
	cursor_y_pos := cursor.pos.y
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
			mut ctx, x + screenspace_x_offset, y + screenspace_y_offset,
			document_line_num, cursor_y_pos, from_line_num, relative_line_nums
		)

		is_cursor_line := document_line_num == cursor_y_pos
		if current_mode != .visual_line && is_cursor_line {
			cursor_line_color := ctx.theme().cursor_line_color
			ctx.set_bg_color(draw.Color{ r: cursor_line_color.r, g: cursor_line_color.g, b: cursor_line_color.b })
			ctx.draw_rect(x + screenspace_x_offset + 1, y + screenspace_y_offset, width - (x + screenspace_x_offset), 1)
			ctx.reset_bg_color()
		}
		// draw the line of text, offset by the position of the buffer view
		draw_text_line(
			mut ctx,
			current_mode,
			x + screenspace_x_offset + 1,
			y + screenspace_y_offset,
			document_line_num,
			line,
			syntax_parser.get_line_tokens(document_line_num),
			syntax_def,
			min_x,
			width,
			is_cursor_line,
			cursor,
			// selection_highlight_color
		)

		screenspace_y_offset += 1
		// detect if number of lines drawn would exceed current height of view
		if screenspace_y_offset > height { return }
	}
}

// NOTE(tauraamui) [15/06/2025]: should add this to themes, not in palette though.
const line_num_fg_color = tui.Color{ r: 117, g: 118, b: 120 }

fn draw_line_number(
	mut ctx draw.Contextable,
	x int, y int,
	document_line_num int, cursor_y_pos int, from int, relative_line_nums bool
) {
	defer { ctx.reset_color() }
	ctx.set_color(draw.Color{ line_num_fg_color.r, line_num_fg_color.g, line_num_fg_color.b })

	// NOTE(tauraamui) [04/06/2025]: there's a fair amount of repeatition in this match
	//                               but I think it's probably fine
	line_num_str := match relative_line_nums {
		true {
			match document_line_num == cursor_y_pos {
				true { "${document_line_num + 1}" }
				else {
					cursor_screenspace_y := cursor_y_pos - from
					match true {
						y < cursor_screenspace_y { "${cursor_screenspace_y - y}" }
						y > cursor_screenspace_y { "${y - cursor_screenspace_y}" }
						else { "${document_line_num + 1}" }
					}
				}
			}
		}
		else {
			"${document_line_num + 1}"
		}
	}

	ctx.draw_text(x - line_num_str.runes().len, y, line_num_str)
}

fn draw_text_line(
	mut ctx draw.Contextable,
	current_mode core.Mode,
	x int, y int,
	document_line_num int,
	line string,
	line_tokens []syntax.Token,
	syntax_def syntax.Syntax,
	min_x int, width int,
	is_cursor_line bool,
	cursor BufferCursor,
) {
	max_width := width - x
	if current_mode != .visual_line && is_cursor_line { // no point in setting the bg in this case
		cursor_line_color := ctx.theme().cursor_line_color
		ctx.set_bg_color(draw.Color{ r: cursor_line_color.r, g: cursor_line_color.g, b: cursor_line_color.b })
		defer { ctx.reset_bg_color() }
	}

	mut visual_x_offset := x
	mut previous_token := ?syntax.Token(none)
	for i, token in line_tokens {
		current_token := token
		mut next_token := ?syntax.Token(none)
		if i + 1 < line_tokens.len - 1 { next_token = line_tokens[i + 1] }
		cur_token_bounds := resolve_token_bounds(current_token.start(), current_token.end(), min_x) or { continue }

		visual_x_offset += render_token(
			mut ctx, current_mode, line,
			cur_token_bounds, previous_token,
			current_token, next_token, syntax_def,
			x, max_width,
			visual_x_offset, y,
			cursor.resolve_line_selection_span(current_mode, line.runes().len, document_line_num)
		)

		previous_token = current_token
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

fn resolve_token_fg_color(
	theme themelib.Theme,
	segment_to_render string,
	previous_token ?syntax.Token,
	current_token syntax.Token,
	next_token ?syntax.Token,
	syntax_def syntax.Syntax,
) tui.Color {
	prev_token_type := if prev_token := previous_token { prev_token.t_type() } else { .whitespace }
	next_token_type := if n_token := next_token { n_token.t_type() } else { .whitespace }

	cur_token_type := current_token.t_type()
	resolved_token_type := match true {
		cur_token_type               == .comment { cur_token_type }
		cur_token_type               == .string  { cur_token_type }
		(prev_token_type != .whitespace) || (next_token_type != .whitespace) { cur_token_type }
		segment_to_render in syntax_def.literals { syntax.TokenType.literal }
		segment_to_render in syntax_def.keywords { syntax.TokenType.keyword }
		segment_to_render in syntax_def.builtins { syntax.TokenType.builtin }
		else { cur_token_type }
	}

	return theme.pallete[resolved_token_type]
}

fn render_token(
	mut ctx draw.Contextable,
	current_mode core.Mode, line string,
	cur_token_bounds TokenBounds,
	previous_token ?syntax.Token,
	current_token syntax.Token,
	next_token ?syntax.Token,
	syntax_def syntax.Syntax,
	base_x int, max_width int,
	x_offset int, y int,
	selection_span SelectionSpan
) int {
	mut segment_to_render := line.runes()[cur_token_bounds.start..cur_token_bounds.end].string().replace("\t", " ".repeat(4))
	segment_to_render = utf8.str_clamp_to_visible_length(segment_to_render, max_width - (x_offset - base_x))
	if segment_to_render.runes().len == 0 { return 0 }

	fg_color := resolve_token_fg_color(
		ctx.theme(), segment_to_render, previous_token,
		current_token, next_token, syntax_def
	)

	return render_segment(mut ctx, current_mode, cur_token_bounds, segment_to_render, fg_color, x_offset, y, selection_span)
}

fn render_segment(
	mut ctx draw.Contextable, current_mode core.Mode,
	segment_bounds TokenBounds, segment string, fg_color tui.Color,
	x int, y int, selection_span SelectionSpan
) int {
	// NOTE(tauraamui) [17/06/2025]: Just to be extremely explicit (in comment form) here, the logic flow
	//                               for this function is to separate eventual text rendering of tokens or parts
	//                               of tokens with the correct background spanning the correct amount of said token,
	//                               based on the current "leader mode".
	//                                                   visual_line -> render whole token with selection background color
	//                                                  /
	//                               The flow is - mode -> visual -> cut up token and render in pieces if necessary
	//                                                  \
	//                                                   anything_else -> render token as is (do not change the bg_color)
	match current_mode {
		.visual_line { return render_segment_in_visual_line_mode(mut ctx, segment, fg_color, x, y, selection_span.full) }
		.visual      { return render_segment_in_visual_mode(mut ctx, segment_bounds, segment, fg_color, x, y, selection_span) }
		else {} // do nothing, fallthrough please!
	}

	ctx.set_color(draw.Color{ fg_color.r, fg_color.g, fg_color.b })
	ctx.draw_text(x, y, segment)
	return utf8_str_visible_length(segment)
}

fn render_segment_in_visual_line_mode(mut ctx draw.Contextable, segment string, fg_color tui.Color, x int, y int, is_selected bool) int {
	ctx.set_color(draw.Color{ fg_color.r, fg_color.g, fg_color.b })
	if is_selected {
		bg_color := ctx.theme().selection_highlight_color
		ctx.set_bg_color(draw.Color{ bg_color.r, bg_color.g, bg_color.b })
		defer { ctx.reset_bg_color() }
	}

	ctx.draw_text(x, y, segment)
	return utf8_str_visible_length(segment)
}

fn render_segment_in_visual_mode(
	mut ctx draw.Contextable, segment_bounds TokenBounds,
	segment string, fg_color tui.Color,
	x int, y int, selection_span SelectionSpan
) int {
	if selection_span.full { return render_segment_in_visual_mode_current_line_is_fully_selected(mut ctx, segment_bounds, segment, fg_color, x, y) }

	ctx.set_color(draw.Color{ fg_color.r, fg_color.g, fg_color.b })
	ctx.draw_text(x, y, segment)
	return utf8_str_visible_length(segment)
}

fn render_segment_in_visual_mode_current_line_is_fully_selected(
	mut ctx draw.Contextable, segment_bounds TokenBounds,
	segment string, fg_color tui.Color,
	x int, y int
) int {
	bg_color := ctx.theme().selection_highlight_color
	ctx.set_bg_color(draw.Color{ bg_color.r, bg_color.g, bg_color.b })
	defer { ctx.reset_bg_color() }

	ctx.set_color(draw.Color{ fg_color.r, fg_color.g, fg_color.b })
	ctx.draw_text(x, y, segment)
	return utf8_str_visible_length(segment)
}

