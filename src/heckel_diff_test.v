module main

fn test_sequence_matcher() {
	a := ["MUCH", "WRITING", "IS", "LIKE", "SNOW", ",",
             "A", "MASS", "OF", "LONG", "WORDS", "AND",
             "PHRASES", "FALLS", "UPON", "THE", "RELEVANT",
             "FACTS", "COVERING", "UP", "THE", "DETAILS", "."]
	b := ["A", "MASS", "OF", "LATIN", "WORDS", "FALLS",
             "UPON", "THE", "RELEVANT", "FACTS", "LIKE", "SOFT",
             "SNOW", ",", "COVERING", "UP", "THE", "DETAILS", "."]
	run_diff(a, b)
	assert 1 == 2
}

