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

module buffers

pub struct LineIterator {
	data_ref            []rune
	exclusion_range_min int
	exclusion_range_max int
mut:
	idx int
}

pub fn LineIterator.new(data_ref []rune, exclusion_range_min int, exclusion_range_max int) LineIterator {
	return LineIterator{
		data_ref:            data_ref
		exclusion_range_min: exclusion_range_min
		exclusion_range_max: exclusion_range_max
	}
}

pub fn (mut iter LineIterator) next() ?[]rune {
	// NOTE(tauraamui): skip past gap if we're inside it
	if iter.idx >= iter.exclusion_range_min && iter.idx < iter.exclusion_range_max {
		iter.idx = iter.exclusion_range_max
	}

	if iter.idx >= iter.data_ref.len {
		return none
	}

	line_start := iter.idx

	for i in iter.idx .. iter.data_ref.len {
		if i >= iter.exclusion_range_min && i < iter.exclusion_range_max {
			continue
		}

		if iter.data_ref[i] == `\n` {
			iter.idx = i + 1
			return iter.build_line(line_start, i)
		}
	}

	// //NOTE(tauraamui): return remaining content
	iter.idx = iter.data_ref.len
	return iter.build_line(line_start, iter.data_ref.len)
}

fn (iter LineIterator) build_line(start int, end int) []rune {
	gap_min := iter.exclusion_range_min
	gap_max := iter.exclusion_range_max

	// //NOTE(tauraamui): line entirely before gap
	if end <= gap_min {
		return iter.data_ref[start..end]
	}

	// NOTE(tauraamui): line entirely after gap
	if start >= gap_max {
		return iter.data_ref[start..end]
	}

	// NOTE(tauraamui): line spans the gap
	mut result := []rune{}
	if start < gap_min {
		result << iter.data_ref[start..gap_min]
	}
	if end > gap_max {
		result << iter.data_ref[gap_max..end]
	}
	return result
}
