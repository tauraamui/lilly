module main

import lib.workspace

fn syntax_for_testing() workspace.Syntax {
	return workspace.Syntax{
		keywords: [ "if" ]
		literals: [ "true" ]
	}
}

fn test_resolve_line_segments() {
	line := "if true == 'stringvalue'"
	segments := resolve_line_segments_2(syntax_for_testing(), line)

	assert segments == [
		LineSegment2{
			start: 0,
			end: 1,
			typ: .a_key,
			fg_color: Color{1, 1, 1},
			bg_color: Color{3, 3, 3}
		},
		LineSegment2{
			start: 3,
			end: 6,
			typ: .a_lit,
			fg_color: Color{1, 1, 1},
			bg_color: Color{3, 3, 3}
		}
	]
	assert true == false
}
