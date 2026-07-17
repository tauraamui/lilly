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

module glyphs

pub const block = '█'

// box_junction picks the single box-drawing glyph for a divider cell from the
// four sides a divider line continues toward. This lets junctions where panes
// meet render the correct tee/cross instead of a fixed, often-wrong corner.
pub fn box_junction(up bool, down bool, left bool, right bool) string {
	if up && down && left && right {
		return '┼'
	}
	if up && down && right {
		return '├'
	}
	if up && down && left {
		return '┤'
	}
	if down && left && right {
		return '┬'
	}
	if up && left && right {
		return '┴'
	}
	if down && right {
		return '┌'
	}
	if down && left {
		return '┐'
	}
	if up && right {
		return '└'
	}
	if up && left {
		return '┘'
	}
	if left || right {
		return '─'
	}
	return '│'
}

pub const slant_left_flat_bottom = ''
pub const left_rounded = ''
pub const slant_left_flat_top = ''
pub const slant_right_flat_bottom = ''
pub const right_rounded = ''
pub const slant_right_flat_top = ''
