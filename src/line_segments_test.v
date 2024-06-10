module main

import lib.workspace

fn syntax_for_testing() workspace.Syntax {
	return workspace.Syntax{
		keywords: [ "if", "true" ]
	}
}

fn test_resolve_line_segments() {
	line := "if true == 'stringvalue'"
	segments := resolve_line_segments_2(syntax_for_testing(), line)

	assert segments == []
	assert true == false
}
