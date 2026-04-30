module syntax

fn test_markdown_parse_line_emits_expected_tokens() {
	mock_line := '# This is a header'

	mut parser_state := MarkdownParserState{}
	markdown_tokens := parse_markdown_line(mut parser_state, mock_line)
	/*
	assert markdown_tokens == [
		MarkdownToken{ t_type: .header }
		MarkdownToken{ t_type: .header }
		MarkdownToken{ t_type: .header }
		MarkdownToken{ t_type: .header }
		MarkdownToken{ t_type: .header }
	]
	*/
	
	for i, mt in markdown_tokens {
		println('i: ${i}, token: "${mock_line[mt.start..mt.end]}"')
	}
	
	assert false
}

