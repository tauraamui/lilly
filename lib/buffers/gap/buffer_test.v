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

module gap

const test_gap_size = 8

fn test_gap_init() {
	assert Buffer.new(test_gap_size).buf.len == test_gap_size
}

fn test_move_cursor_left() {
	mut gb := Buffer.new(test_gap_size)
	gb.insert(u8(`c`))
	assert gb.buf[gb.ccur - 1] == u8(`c`)
	assert gb.ccur == 1

	gb.move_cur_left()
	assert gb.ccur == 0
	assert gb.cend == u64(test_gap_size - 1)

	gb.move_cur_left()
	assert gb.ccur == 0
	assert gb.cend == u64(test_gap_size - 1)
}

fn test_insert_into_gap_sets_slot_and_increments_cursor() {
	mut gb := Buffer.new(test_gap_size)
	gb.insert(u8(`c`))
	assert gb.buf[gb.ccur - 1] == u8(`c`)
	assert gb.ccur == 1

	gb.insert(u8(`d`))
	assert gb.buf[gb.ccur - 1] == u8(`d`)
	assert gb.ccur == 2

	assert gb.str() == 'cd'
	assert gb.rawstr() == 'cd______'
}

fn test_insert_beyond_gap_clamped() {
	mut gb := Buffer.new(8)
	gb.insert(u8(`c`))
	assert gb.buf[gb.ccur - 1] == u8(`c`)
	assert gb.ccur == 1
	assert gb.rawstr() == 'c_______'

	gb.insert(u8(`d`))
	assert gb.buf[gb.ccur - 1] == u8(`d`)
	assert gb.ccur == 2
	assert gb.rawstr() == 'cd______'

	gb.insert(u8(`e`))
	assert gb.buf[gb.ccur - 1] == u8(`e`)
	assert gb.ccur == 3
	assert gb.rawstr() == 'cde_____'

	gb.insert(u8(`f`))
	assert gb.buf[gb.ccur - 1] == u8(`f`)
	assert gb.ccur == 4
	assert gb.rawstr() == 'cdef____'

	gb.insert(u8(`g`))
	assert gb.buf[gb.ccur - 1] == u8(`g`)
	assert gb.ccur == 5
	assert gb.rawstr() == 'cdefg___'

	gb.insert(u8(`h`))
	assert gb.buf[gb.ccur - 1] == u8(`h`)
	assert gb.ccur == 6
	assert gb.rawstr() == 'cdefgh__'

	gb.insert(u8(`i`))
	assert gb.buf[gb.ccur - 1] == u8(`i`)
	assert gb.ccur == 7
	assert gb.rawstr() == 'cdefghi_'

	gb.insert(u8(`j`))
	assert gb.buf[gb.ccur - 1] == u8(`j`)
	assert gb.ccur == 8
	assert gb.rawstr() == 'cdefghij'

	gb.insert(u8(`k`))
	assert gb.buf[gb.ccur - 1] == u8(`k`)
	assert gb.ccur == 9
	assert gb.rawstr() == 'cdefghijk_______'
}

fn test_move_cur_to_start_preserves_content() {
	mut gb := Buffer.new(test_gap_size)
	gb.insert(u8(`a`))
	gb.insert(u8(`b`))
	gb.insert(u8(`c`))
	gb.move_cur_to_start()
	assert gb.str() == 'abc'
	gb.insert(u8(`>`))
	assert gb.str() == '>abc'
}

fn test_move_cur_to_start_with_right_side_content() {
	mut gb := Buffer.new(test_gap_size)
	gb.insert(u8(`a`))
	gb.insert(u8(`b`))
	gb.insert(u8(`c`))
	gb.insert(u8(`d`))
	gb.move_cur_left()
	gb.move_cur_left()
	gb.move_cur_to_start()
	assert gb.str() == 'abcd'
	gb.insert(u8(`>`))
	assert gb.str() == '>abcd'
}

fn test_insert_many_chars_grows_without_panic() {
	mut gb := Buffer.new(4)
	for _ in 0 .. 20 {
		gb.insert(u8(`a`))
	}
	assert gb.str().len == 20
}

fn test_move_cur_to_start_clears_vacated_bytes() {
	mut gb := Buffer.new(test_gap_size)
	gb.insert_bytes('abc'.bytes())
	gb.move_cur_to_start()
	assert gb.rawstr() == '_____abc'
	assert gb.str() == 'abc'
}

fn test_move_cur_to_start_when_content_is_longer_than_gap() {
	mut gb := Buffer.new(test_gap_size)
	gb.insert_bytes('abcdef'.bytes())
	gb.move_cur_to_start()
	assert gb.rawstr() == '__abcdef'
	gb.insert(u8(`>`))
	assert gb.str() == '>abcdef'
}

fn test_insert_bytes_within_gap() {
	mut gb := Buffer.new(test_gap_size)
	gb.insert_bytes('abc'.bytes())
	assert gb.ccur == 3
	assert gb.rawstr() == 'abc_____'
}

fn test_insert_bytes_beyond_gap_grows_once_and_keeps_right_side() {
	mut gb := Buffer.new(4)
	gb.insert_bytes('xy'.bytes())
	gb.move_cur_left()
	gb.move_cur_left()
	gb.insert_bytes('abcdefghij'.bytes())
	assert gb.str() == 'abcdefghijxy'
	assert gb.buf.len == 12
	gb.insert(u8(`>`))
	assert gb.str() == 'abcdefghij>xy'
}

fn test_reserve_grows_gap_to_requested_size_once() {
	mut gb := Buffer.new(4)
	gb.insert(u8(`a`))
	gb.reserve(100)
	assert gb.gap_size() == 100
	assert gb.buf.len == 101
	gb.reserve(50)
	assert gb.buf.len == 101
	gb.insert_bytes('bc'.bytes())
	assert gb.str() == 'abc'
}
