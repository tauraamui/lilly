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

module diff

// max_edits bounds how many line edits the Myers search looks for before it
// gives up and reports everything between the common prefix and suffix as one
// replaced block. The search keeps a trace that grows with the square of the
// edits found, so without a bound a file that was rewritten wholesale would
// cost far more memory than the result is worth.
const max_edits = 1000

// Hunk is one run of changed lines. old_count lines starting at old_start in
// the old text were replaced by new_count lines starting at new_start in the
// new text. Either count may be zero: a pure insertion removes nothing, and a
// pure deletion adds nothing, in which case new_start is the line in the new
// text that now follows where the removed lines were.
pub struct Hunk {
pub:
	old_start int
	old_count int
	new_start int
	new_count int
}

// lines finds the hunks that turn old into new, in order.
pub fn lines(old []string, new []string) []Hunk {
	// lines are compared as ids so the search compares ints, not strings
	mut ids := map[string]int{}
	a := intern(old, mut ids)
	b := intern(new, mut ids)

	mut prefix := 0
	for prefix < a.len && prefix < b.len && a[prefix] == b[prefix] {
		prefix++
	}
	mut suffix := 0
	for suffix < a.len - prefix && suffix < b.len - prefix
		&& a[a.len - 1 - suffix] == b[b.len - 1 - suffix] {
		suffix++
	}

	mid_a := a[prefix..a.len - suffix]
	mid_b := b[prefix..b.len - suffix]
	if mid_a.len == 0 && mid_b.len == 0 {
		return []
	}

	mut deleted := []bool{len: mid_a.len}
	mut inserted := []bool{len: mid_b.len}
	if !myers(mid_a, mid_b, mut deleted, mut inserted) {
		return [
			Hunk{
				old_start: prefix
				old_count: mid_a.len
				new_start: prefix
				new_count: mid_b.len
			},
		]
	}

	mut hunks := []Hunk{}
	mut i := 0
	mut j := 0
	for i < mid_a.len || j < mid_b.len {
		if i < mid_a.len && j < mid_b.len && !deleted[i] && !inserted[j] {
			i++
			j++
			continue
		}
		start_i, start_j := i, j
		for (i < mid_a.len && deleted[i]) || (j < mid_b.len && inserted[j]) {
			if i < mid_a.len && deleted[i] {
				i++
			} else {
				j++
			}
		}
		hunks << Hunk{
			old_start: prefix + start_i
			old_count: i - start_i
			new_start: prefix + start_j
			new_count: j - start_j
		}
	}
	return hunks
}

fn intern(lines []string, mut ids map[string]int) []int {
	mut out := []int{len: lines.len}
	for i, line in lines {
		out[i] = ids[line] or {
			id := ids.len
			ids[line] = id
			id
		}
	}
	return out
}

// myers marks which lines of a were deleted and which of b were inserted by a
// shortest edit script. It reports false, marking nothing, when the script
// would be longer than max_edits.
fn myers(a []int, b []int, mut deleted []bool, mut inserted []bool) bool {
	n, m := a.len, b.len
	limit := if n + m < max_edits { n + m } else { max_edits }
	offset := limit + 1
	mut v := []int{len: 2 * limit + 3}
	// trace[d] holds v for diagonals -d..d as it stood before step d, which is
	// all the backtrack needs to find each step's predecessor
	mut trace := [][]int{cap: 16}
	mut found := -1
	for d in 0 .. limit + 1 {
		trace << v[offset - d..offset + d + 1].clone()
		for k := -d; k <= d; k += 2 {
			mut x := if k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1]) {
				v[offset + k + 1]
			} else {
				v[offset + k - 1] + 1
			}
			mut y := x - k
			for x < n && y < m && a[x] == b[y] {
				x++
				y++
			}
			v[offset + k] = x
			if x >= n && y >= m {
				found = d
				break
			}
		}
		if found >= 0 {
			break
		}
	}
	if found < 0 {
		return false
	}

	mut x, mut y := n, m
	for d := found; d > 0; d-- {
		prev := trace[d]
		k := x - y
		prev_k := if k == -d || (k != d && prev[k - 1 + d] < prev[k + 1 + d]) {
			k + 1
		} else {
			k - 1
		}
		prev_x := prev[prev_k + d]
		prev_y := prev_x - prev_k
		for x > prev_x && y > prev_y {
			x--
			y--
		}
		if prev_k == k + 1 {
			inserted[prev_y] = true
		} else {
			deleted[prev_x] = true
		}
		x, y = prev_x, prev_y
	}
	return true
}
