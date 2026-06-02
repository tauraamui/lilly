module gap

const test_gap_size = 1024 / 2

fn test_gap_init() {
	assert Buffer.new(test_gap_size).buf.len == test_gap_size
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
}

