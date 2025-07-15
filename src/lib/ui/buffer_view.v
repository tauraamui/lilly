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
	syntaxes  []syntax.Syntax
	syntax_id int
mut:
	parser   syntax.Parser
}

pub fn BufferView.new(syntaxes []syntax.Syntax, syntax_id int) BufferView {
	return BufferView{
		syntaxes: syntaxes
		syntax_id: syntax_id
		parser: syntax.Parser.new(syntaxes)
	}
}

@[params]
pub struct BufferViewDrawArgs {
pub:
	buf buffer.Buffer
	x int
	y int
	width int
	height int
	from_line_num int
	min_x int
	relative_line_nums bool
	current_mode core.Mode
	cursor BufferCursor
}

pub fn (mut buf_view BufferView) draw(mut ctx draw.Contextable, args BufferViewDrawArgs) {
	cursor_y_pos := args.cursor.pos.y
	syntax_def := buf_view.syntaxes[buf_view.syntax_id] or { syntax.Syntax{} }

	mut screenspace_x_offset := args.buf.num_of_lines().str().runes().len
	mut screenspace_y_offset := 0

	buf_view.parser.reset()
	mut syntax_parser := buf_view.parser

	for document_line_num, line in args.buf.line_iterator() {
		syntax_parser.parse_line(document_line_num, line)
		// if we haven't reached the line to render in the document yet, skip this
		if document_line_num < args.from_line_num { continue }

		draw_line_number(
			mut ctx,
			x: args.x + screenspace_x_offset,
			y: args.y + screenspace_y_offset,
			from: args.from_line_num,
			cursor_y_pos: cursor_y_pos,
			document_line_num: document_line_num,
			relative_line_nums: args.relative_line_nums
		)

		is_cursor_line := (document_line_num == cursor_y_pos) && !(args.current_mode == .visual || args.current_mode == .visual_line)
		if args.current_mode != .visual_line && is_cursor_line {
			cursor_line_color := ctx.theme().cursor_line_color
			ctx.set_bg_color(draw.Color{ r: cursor_line_color.r, g: cursor_line_color.g, b: cursor_line_color.b })
			ctx.draw_rect(args.x + screenspace_x_offset + 1, args.y + screenspace_y_offset, args.width - (args.x + screenspace_x_offset), 1)
			ctx.reset_bg_color()
		}
		// draw the line of text, offset by the position of the buffer view
		draw_text_line(
			mut ctx,
			x: args.x + screenspace_x_offset + 1,
			y: args.y + screenspace_y_offset,
			width: args.width,
			min_x: args.min_x,
			document_line_num: document_line_num,
			is_cursor_line: is_cursor_line,
			line: line,
			line_tokens: syntax_parser.get_line_tokens(document_line_num),
			syntax_def: syntax_def,
			current_mode: args.current_mode,
			cursor: args.cursor,
		)

		screenspace_y_offset += 1
		if screenspace_y_offset > args.height { return }
	}
}

@[params]
struct DrawLineNumberArgs {
	x int
	y int
	from int
	cursor_y_pos int
	document_line_num int
	relative_line_nums bool
}

fn draw_line_number(
	mut ctx draw.Contextable,
	args DrawLineNumberArgs
) {
	defer { ctx.reset_color() }
	line_num_fg_color := ctx.theme().line_number_color
	ctx.set_color(draw.Color{ line_num_fg_color.r, line_num_fg_color.g, line_num_fg_color.b })

	// NOTE(tauraamui) [04/06/2025]: there's a fair amount of repeatition in this match
	//                               but I think it's probably fine
	line_num_str := match args.relative_line_nums {
		true {
			match args.document_line_num == args.cursor_y_pos {
				true { "${args.document_line_num + 1}" }
				else {
					cursor_screenspace_y := args.cursor_y_pos - args.from
					match true {
						args.y < cursor_screenspace_y { "${cursor_screenspace_y - args.y}" }
						args.y > cursor_screenspace_y { "${args.y - cursor_screenspace_y}" }
						else { "${args.document_line_num + 1}" }
					}
				}
			}
		}
		else {
			"${args.document_line_num + 1}"
		}
	}

	ctx.draw_text(args.x - line_num_str.runes().len, args.y, line_num_str)
}

@[params]
struct DrawTextLineArgs {
	x int
	y int
	width int
	min_x int
	document_line_num int
	is_cursor_line bool
	line string
	line_tokens []syntax.Token
	syntax_def syntax.Syntax
	current_mode core.Mode
	cursor BufferCursor
}

fn draw_text_line(
	mut ctx draw.Contextable,
	args DrawTextLineArgs
) {
	max_width := args.width - args.x
	if args.current_mode != .visual_line && args.is_cursor_line { // no point in setting the bg in this case
		cursor_line_color := ctx.theme().cursor_line_color
		ctx.set_bg_color(draw.Color{ r: cursor_line_color.r, g: cursor_line_color.g, b: cursor_line_color.b })
		defer { ctx.reset_bg_color() }
	}

	mut visual_x_offset := args.x
	mut previous_token := ?syntax.Token(none)
	for i, token in args.line_tokens {
		current_token := token
		mut next_token := ?syntax.Token(none)

		if i + 1 < args.line_tokens.len - 1 { next_token = args.line_tokens[i + 1] }

		cur_token_bounds := resolve_token_bounds(
			token_start: current_token.start(),
			token_end: current_token.end(),
			min_x: args.min_x
		) or { continue }

		visual_x_offset += render_token(
			mut ctx,
			y: args.y,
			base_x: args.x,
			max_width: max_width,
			x_offset: visual_x_offset,
			document_line_num: args.document_line_num,
			line: args.line,
			cursor: args.cursor,
			previous_token: previous_token,
			current_token: current_token,
			next_token: next_token,
			cur_token_bounds: cur_token_bounds,
			syntax_def: args.syntax_def,
			current_mode: args.current_mode
		)

		previous_token = current_token
	}
}

struct TokenBounds {
	start int
	end   int
}

@[params]
struct ResolveTokenBoundsArgs {
	token_start int
	token_end int
	min_x int
}

fn resolve_token_bounds(args ResolveTokenBoundsArgs) ?TokenBounds {
	token_start := args.token_start
	token_end := args.token_end
	min_x := args.min_x
	if token_end < token_start { return none }
	if token_end < min_x { return none }
	if token_end > min_x && token_start < min_x {
		return TokenBounds{ start: min_x, end: token_end }
	}
	return TokenBounds{ start: token_start, end: token_end }
}

@[params]
struct ResolveTokenFGColorArgs {
	theme themelib.Theme
	segment_to_render string
	previous_token ?syntax.Token
	current_token syntax.Token
	next_token ?syntax.Token
	syntax_def syntax.Syntax
}

fn resolve_token_fg_color(args ResolveTokenFGColorArgs) tui.Color {
	prev_token_type := if prev_token := args.previous_token { prev_token.t_type() } else { .whitespace }
	next_token_type := if n_token := args.next_token { n_token.t_type() } else { .whitespace }

	cur_token_type := args.current_token.t_type()
	resolved_token_type := match true {
		cur_token_type               == .comment { cur_token_type }
		cur_token_type               == .string  { cur_token_type }
		(prev_token_type != .whitespace) || (next_token_type != .whitespace) { cur_token_type }
		args.segment_to_render in args.syntax_def.literals { syntax.TokenType.literal }
		args.segment_to_render in args.syntax_def.keywords { syntax.TokenType.keyword }
		args.segment_to_render in args.syntax_def.builtins { syntax.TokenType.builtin }
		else { cur_token_type }
	}

	return args.theme.pallete[resolved_token_type]
}

@[params]
struct RenderTokenArgs {
	y int
	base_x int
	max_width int
	x_offset int
	document_line_num int
	line string
	cursor BufferCursor
	previous_token ?syntax.Token
	current_token syntax.Token
	next_token ?syntax.Token
	cur_token_bounds TokenBounds
	syntax_def syntax.Syntax
	current_mode core.Mode
}

fn render_token(
	mut ctx draw.Contextable,
	args RenderTokenArgs
) int {
	mut segment_to_render := args.line.runes()[args.cur_token_bounds.start..args.cur_token_bounds.end].string().replace("\t", " ".repeat(4))
	segment_to_render = utf8.str_clamp_to_visible_length(segment_to_render, args.max_width - (args.x_offset - args.base_x))
	if segment_to_render.runes().len == 0 { return 0 }

	fg_color := resolve_token_fg_color(
		theme: ctx.theme(),
		segment_to_render: segment_to_render,
		previous_token: args.previous_token,
		current_token: args.current_token,
		next_token: args.next_token,
		syntax_def: args.syntax_def
	)

	mut sel_span := ?SelectionSpan(none)
	if args.cursor.y_within_selection(args.document_line_num) {
		sel_span = args.cursor.resolve_line_selection_span(args.current_mode, args.line.runes().len, args.document_line_num)
	}

	return render_segment(
		mut ctx,
		x: args.x_offset, y: args.y,
		segment: segment_to_render,
		fg_color: fg_color,
		selection_span: sel_span,
		segment_bounds: args.cur_token_bounds,
		current_mode: args.current_mode
	)
}

@[params]
struct RenderSegmentArgs {
	x int
	y int
	segment string
	fg_color tui.Color
	selection_span ?SelectionSpan
	segment_bounds TokenBounds
	current_mode core.Mode
	is_selected bool
}

@[params]
struct RenderSegmentArgsWithUnwrappedSelectionSpan {
	RenderSegmentArgs
	unwrapped_selection_span SelectionSpan
}

fn render_segment(
	mut ctx draw.Contextable, args RenderSegmentArgs) int {
	// NOTE(tauraamui) [17/06/2025]: Just to be extremely explicit (in comment form) here, the logic flow
	//                               for this function is to separate eventual text rendering of tokens or parts
	//                               of tokens with the correct background spanning the correct amount of said token,
	//                               based on the current "leader mode".
	//                                                   visual_line -> render whole token with selection background color
	//                                                  /
	//                               The flow is - mode -> visual -> cut up token and render in pieces if necessary
	//                                                  \
	//                                                   anything_else -> render token as is (do not change the bg_color)
	if unwrapped_selection_span := args.selection_span {
		match args.current_mode {
			.visual_line { return render_segment_in_visual_line_mode(
					mut ctx, x: args.x, y: args.y, segment: args.segment, fg_color: args.fg_color, is_selected: unwrapped_selection_span.full
				)
			}
			.visual { return render_segment_in_visual_mode(
					mut ctx, x: args.x, y: args.y, segment: args.segment, segment_bounds: args.segment_bounds, fg_color: args.fg_color, selection_span: unwrapped_selection_span
				)
			}
			else { return 0 } // should not be possible to reach, consider adding an assert here
		}
	}

	ctx.set_color(draw.Color{ args.fg_color.r, args.fg_color.g, args.fg_color.b })
	ctx.draw_text(args.x, args.y, args.segment)
	return utf8_str_visible_length(args.segment)
}

fn render_segment_in_visual_line_mode(mut ctx draw.Contextable, args RenderSegmentArgs) int {
	ctx.set_color(draw.Color{ args.fg_color.r, args.fg_color.g, args.fg_color.b })
	if args.is_selected {
		bg_color := ctx.theme().selection_highlight_color
		ctx.set_bg_color(draw.Color{ bg_color.r, bg_color.g, bg_color.b })
		defer { ctx.reset_bg_color() }
	}

	ctx.draw_text(args.x, args.y, args.segment)
	return utf8_str_visible_length(args.segment)
}

fn render_segment_in_visual_mode(mut ctx draw.Contextable, args RenderSegmentArgs) int {
	unwrapped_selection_span := args.selection_span or { return 0 }
	if unwrapped_selection_span.full {
		return render_segment_in_visual_mode_current_line_is_fully_selected(
			mut ctx, x: args.x, y: args.y, fg_color: args.fg_color, segment: args.segment, segment_bounds: args.segment_bounds
		)
	}

	segment_before_selection := args.segment_bounds.end < unwrapped_selection_span.min_x
	segment_after_selection := args.segment_bounds.start > unwrapped_selection_span.max_x

	if segment_before_selection || segment_after_selection {
		return render_segment_in_visual_mode_unselected(
			mut ctx, x: args.x, y: args.y, fg_color: args.fg_color, segment: args.segment
		)
	}

	selection_starts_within_segment := args.segment_bounds.start <= unwrapped_selection_span.min_x && args.segment_bounds.end >= unwrapped_selection_span.min_x
	selection_ends_within_segment   := args.segment_bounds.start <= unwrapped_selection_span.max_x && args.segment_bounds.end >= unwrapped_selection_span.max_x

	if selection_starts_within_segment && selection_ends_within_segment {
		return render_segment_in_visual_mode_selection_starts_and_ends_within(
			mut ctx, x: args.x, y: args.y, fg_color: args.fg_color, segment: args.segment, segment_bounds: args.segment_bounds, unwrapped_selection_span: unwrapped_selection_span
		)
	}

	if selection_starts_within_segment && !selection_ends_within_segment {
		return render_segment_in_visual_mode_selection_starts_within_but_does_not_end_within(
			mut ctx, x: args.x, y: args.y, fg_color: args.fg_color, segment: args.segment, segment_bounds: args.segment_bounds, unwrapped_selection_span: unwrapped_selection_span
		)
	}

	if !selection_starts_within_segment && selection_ends_within_segment {
		return render_segment_in_visual_mode_selection_ends_within_but_does_not_start_within(mut ctx, args.segment_bounds, args.segment, args.fg_color, args.x, args.y, unwrapped_selection_span)
	}

	return render_segment_in_visual_mode_current_line_is_fully_selected(
		mut ctx, x: args.x, y: args.y, fg_color: args.fg_color, segment: args.segment, segment_bounds: args.segment_bounds
	)
}

fn render_segment_in_visual_mode_unselected(mut ctx draw.Contextable, args RenderSegmentArgs) int {
	ctx.set_color(draw.Color{ args.fg_color.r, args.fg_color.g, args.fg_color.b })
	ctx.draw_text(args.x, args.y, args.segment)
	return utf8_str_visible_length(args.segment)
}

fn render_segment_in_visual_mode_current_line_is_fully_selected(mut ctx draw.Contextable, args RenderSegmentArgs) int {
	bg_color := ctx.theme().selection_highlight_color
	ctx.set_bg_color(draw.Color{ bg_color.r, bg_color.g, bg_color.b })
	defer { ctx.reset_bg_color() }

	ctx.set_color(draw.Color{ args.fg_color.r, args.fg_color.g, args.fg_color.b })
	ctx.draw_text(args.x, args.y, args.segment)
	return utf8_str_visible_length(args.segment)
}

fn render_segment_in_visual_mode_selection_starts_and_ends_within(mut ctx draw.Contextable, args RenderSegmentArgsWithUnwrappedSelectionSpan) int {
	selected_segment_span_start := args.unwrapped_selection_span.min_x - args.segment_bounds.start
	selected_segment_span_end   := args.unwrapped_selection_span.max_x - args.segment_bounds.start

	mut x_offset := 0

	segment_first_part := args.segment.runes()[..selected_segment_span_start].string()
	ctx.set_color(draw.Color{ args.fg_color.r, args.fg_color.g, args.fg_color.b })
	ctx.draw_text(args.x, args.y, segment_first_part)

	x_offset += utf8_str_visible_length(segment_first_part)

	segment_selected_part := args.segment.runes()[selected_segment_span_start..selected_segment_span_end].string()
	bg_color := ctx.theme().selection_highlight_color
	ctx.set_bg_color(draw.Color{ bg_color.r, bg_color.g, bg_color.b })
	ctx.reset_color()
	ctx.draw_text(args.x + x_offset, args.y, segment_selected_part)

	x_offset += utf8_str_visible_length(segment_selected_part)

	segment_last_part := args.segment.runes()[selected_segment_span_end..].string()
	ctx.set_color(draw.Color{ args.fg_color.r, args.fg_color.g, args.fg_color.b })
	ctx.reset_bg_color()
	ctx.draw_text(args.x + x_offset, args.y, segment_last_part)
	return utf8_str_visible_length(args.segment)
}

fn render_segment_in_visual_mode_selection_starts_within_but_does_not_end_within(
	mut ctx draw.Contextable, args RenderSegmentArgsWithUnwrappedSelectionSpan
) int {
	selected_segment_span_start := args.unwrapped_selection_span.min_x - args.segment_bounds.start
	segment_unselected_part     := args.segment.runes()[..selected_segment_span_start].string()

	ctx.set_color(draw.Color{ args.fg_color.r, args.fg_color.g, args.fg_color.b })
	ctx.draw_text(args.x, args.y, segment_unselected_part)

	x_offset := utf8_str_visible_length(segment_unselected_part)

	segment_selected_part := args.segment.runes()[selected_segment_span_start..].string()
	bg_color := ctx.theme().selection_highlight_color
	ctx.set_bg_color(draw.Color{ bg_color.r, bg_color.g, bg_color.b })
	ctx.reset_color()
	ctx.draw_text(args.x + x_offset, args.y, segment_selected_part)

	return utf8_str_visible_length(args.segment)
}

fn render_segment_in_visual_mode_selection_ends_within_but_does_not_start_within(
	mut ctx draw.Contextable, segment_bounds TokenBounds,
	segment string, fg_color tui.Color,
	x int, y int, selection_span SelectionSpan
) int {
	selected_segment_span_end := selection_span.max_x - segment_bounds.start
	segment_selected_part     := segment.runes()[..selected_segment_span_end].string()

	bg_color := ctx.theme().selection_highlight_color
	ctx.set_bg_color(draw.Color{ bg_color.r, bg_color.g, bg_color.b })
	ctx.reset_color()
	ctx.draw_text(x, y, segment_selected_part)

	x_offset := utf8_str_visible_length(segment_selected_part)

	segment_last_part := segment.runes()[selected_segment_span_end..].string()
	ctx.set_color(draw.Color{ fg_color.r, fg_color.g, fg_color.b })
	ctx.reset_bg_color()
	ctx.draw_text(x + x_offset, y, segment_last_part)
	return utf8_str_visible_length(segment)
}

