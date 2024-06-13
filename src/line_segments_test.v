module main

import strings

import lib.workspace

fn syntax_for_testing() workspace.Syntax {
	return workspace.Syntax{
		keywords: [ "if" ]
		literals: [ "true" ]
	}
}

fn test_resolve_line_segments() {
	line := "if true && value     == `jiew       fiei` && other == 'stringvalue' && cheese == \"fullstring\""
	line_runes := line.runes()
	segments := resolve_line_segments_2(syntax_for_testing(), line)

	mut render_target := strings.new_builder(64)
	for i, segment in segments {
		if i > 0 {
			render_target.write_runes(line_runes[segments[i - 1].end..segment.start])
		}
		render_target.write_runes(line_runes[segment.start..segment.end])
	}

	assert render_target.str() == line
}

fn test_convert_word_to_segments() {
	syntax := syntax_for_testing()

	assert convert_word_to_segment(syntax, "if", 0, 2) == LineSegment2{
		start: 0,
		end: 1,
		typ: .a_key,
		fg_color: Color{ 1, 1, 1 },
		bg_color: Color{ 3, 3, 3 },
	}

	assert convert_word_to_segment(syntax, "true", 0, 4) == LineSegment2{
		start: 0,
		end: 3,
		typ: .a_lit,
		fg_color: Color{ 1, 1, 1 },
		bg_color: Color{ 3, 3, 3 },
	}

	assert convert_word_to_segment(syntax, "random", 0, 6) == LineSegment2{
		start: 0,
		end: 5,
		typ: .an_unknown,
		fg_color: Color{ 1, 1, 1 },
		bg_color: Color{ 3, 3, 3 },
	}
}
