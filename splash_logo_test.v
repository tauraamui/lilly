// Copyright 2026 The Lilly Edtior contributors
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

import bobatea as tea

// PaintedCell is one drawn cell: which character landed there and in which
// colour. Comparing maps of these is how the prepared-run renderer is held to
// the behaviour of the character-at-a-time one it replaced, since a rendered
// frame captures text but not colour.
struct PaintedCell {
	x      int
	y      int
	char   rune
	colour LogoColour
}

// paint_reference reproduces the original rendering exactly: scan each line for
// `g`/`p` directives, and if present draw the line one character at a time,
// swapping colour on a directive and drawing that cell blank; otherwise draw
// the whole line in whatever colour the previous line left set.
fn paint_reference(data []string) []PaintedCell {
	mut painted := []PaintedCell{}
	mut colour := LogoColour.pink
	for y, line in data {
		mut has_directives := false
		for c in line.split('') {
			if c == 'g' || c == 'p' {
				has_directives = true
				break
			}
		}
		if !has_directives {
			for i, r in line.runes() {
				painted << PaintedCell{i, y, r, colour}
			}
			continue
		}
		for i, r in line.runes() {
			mut to_draw := r
			if r == `g` {
				to_draw = ` `
				colour = .green
			}
			if r == `p` {
				to_draw = ` `
				colour = .pink
			}
			painted << PaintedCell{i, y, to_draw, colour}
		}
	}
	return painted
}

// paint_prepared replays what render_logo now draws, from the prepared runs.
fn paint_prepared(logo SplashLogo) []PaintedCell {
	mut painted := []PaintedCell{}
	for y, line in logo.lines {
		for run in line.runs {
			for i, r in run.text.runes() {
				painted << PaintedCell{run.x + i, y, r, run.colour}
			}
		}
	}
	return painted
}

fn test_prepared_logo_paints_identically_to_char_by_char_rendering() {
	data := logo_contents.to_string().split_into_lines()
	logo := SplashLogo.parse(logo_contents.to_string())

	expected := paint_reference(data)
	actual := paint_prepared(logo)

	assert expected.len > 0
	assert actual.len == expected.len
	for i, cell in expected {
		assert actual[i] == cell, 'cell ${i} differs: expected ${cell}, got ${actual[i]}'
	}
}

fn test_parse_records_visible_length_per_line() {
	logo := SplashLogo.parse(logo_contents.to_string())
	data := logo_contents.to_string().split_into_lines()
	assert logo.lines.len == data.len
	for i, line in logo.lines {
		assert line.visible_len == tea.visible_len(data[i])
	}
	// width is the widest line, which is what a caller would centre against
	mut widest := 0
	for line in logo.lines {
		if line.visible_len > widest {
			widest = line.visible_len
		}
	}
	assert logo.width == widest
}

fn test_parse_threads_colour_across_lines() {
	// a line with no directive of its own inherits the colour the line above
	// left set, which is why parsing cannot be done per line in isolation
	logo := SplashLogo.parse('aaa\ngbbb\nccc')
	assert logo.lines.len == 3
	assert logo.lines[0].runs.len == 1
	assert logo.lines[0].runs[0].colour == .pink
	assert logo.lines[0].runs[0].text == 'aaa'
	assert logo.lines[0].runs[0].x == 0

	// the directive's own cell opens the green run as a space
	assert logo.lines[1].runs.len == 1
	assert logo.lines[1].runs[0].colour == .green
	assert logo.lines[1].runs[0].text == ' bbb'
	assert logo.lines[1].runs[0].x == 0

	assert logo.lines[2].runs.len == 1
	assert logo.lines[2].runs[0].colour == .green
	assert logo.lines[2].runs[0].text == 'ccc'
}

fn test_parse_splits_a_line_into_runs_at_each_directive() {
	logo := SplashLogo.parse('aaglbbpcc')
	assert logo.lines.len == 1
	runs := logo.lines[0].runs
	assert runs.len == 3
	assert runs[0].x == 0
	assert runs[0].text == 'aa'
	assert runs[0].colour == .pink
	// the `g` at index 2 becomes a blank cell heading the green run
	assert runs[1].x == 2
	assert runs[1].text == ' lbb'
	assert runs[1].colour == .green
	// and the `p` at index 6 does the same for the pink run that follows
	assert runs[2].x == 6
	assert runs[2].text == ' cc'
	assert runs[2].colour == .pink
}
