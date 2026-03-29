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

fn test_data_iterator_basic_contiguous_lines() {
	data := [rune(`a`), `b`, `c`, `\n`, `d`, `e`, `f`, `\n`, `g`, `h`, `i`]
	mut iter := LineIterator.new(data, 0, 0)

	assert iter.next()? == [rune(`a`), `b`, `c`]
	assert iter.next()? == [rune(`d`), `e`, `f`]
	assert iter.next()? == [rune(`g`), `h`, `i`]
	assert iter.next() == none
}

fn test_data_iterator_multiple_blank_lines() {
	data := [rune(`a`), `b`, `c`, `\n`, `\n`, `\n`, `d`, `e`, `f`, `\n`, `g`, `h`, `i`]
	mut iter := LineIterator.new(data, 0, 0)

	assert iter.next()? == [rune(`a`), `b`, `c`]
	assert iter.next()? == []
	assert iter.next()? == []
	assert iter.next()? == [rune(`d`), `e`, `f`]
	assert iter.next()? == [rune(`g`), `h`, `i`]
	assert iter.next() == none
}

fn test_data_iterator_leading_and_trailing_single_blank_lines() {
	data := [rune(`\n`), `a`, `b`, `c`, `\n`, `\n`, `\n`, `d`, `e`, `f`, `\n`, `g`, `h`, `i`, `\n`]
	mut iter := LineIterator.new(data, 0, 0)

	assert iter.next()? == []
	assert iter.next()? == [rune(`a`), `b`, `c`]
	assert iter.next()? == []
	assert iter.next()? == []
	assert iter.next()? == [rune(`d`), `e`, `f`]
	assert iter.next()? == [rune(`g`), `h`, `i`]
	assert iter.next() == none
}

fn test_data_iterator_leading_and_trailing_multiple_blank_lines() {
	data := [rune(`\n`), `\n`, `a`, `b`, `c`, `\n`, `\n`, `\n`, `d`, `e`, `f`, `\n`, `g`, `h`,
		`i`, `\n`, `\n`]
	mut iter := LineIterator.new(data, 0, 0)

	assert iter.next()? == []
	assert iter.next()? == []
	assert iter.next()? == [rune(`a`), `b`, `c`]
	assert iter.next()? == []
	assert iter.next()? == []
	assert iter.next()? == [rune(`d`), `e`, `f`]
	assert iter.next()? == [rune(`g`), `h`, `i`]
	assert iter.next()? == []
	assert iter.next() == none
}
