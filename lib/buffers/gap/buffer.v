module gap

pub struct Buffer {
mut:
	buf  []u8
	ccur u64
	cend u64
}

pub fn Buffer.new(size int) Buffer {
	return Buffer{
		buf: []u8{ len: size, cap: size }
		ccur: 0
		cend: u64(size)
	}
}

pub fn (mut gb Buffer) insert(c u8) {
	// NOTE(tauraamui) [2026-06-02]: much prefer the idea the grow only occurs if next insert elapses not before
	if gb.cend - gb.ccur == 0 {
		gb.grow()
	}
	gb.buf[gb.ccur] = c
	gb.ccur += u64(1)
}

pub fn (mut gb Buffer) delete() {
	if gb.cend == u64(gb.buf.len) { return }
	gb.cend += 1
}

pub fn (mut gb Buffer) backspace() {
	if gb.ccur == 0 { return }
	gb.ccur -= 1
}

pub fn (mut gb Buffer) move_cur_left() {
	if gb.ccur == 0 { return }
	gb.ccur -= 1
	gb.buf[gb.cend - 1] = gb.buf[gb.ccur]
	gb.buf[gb.ccur] = 0x0
	gb.cend -= 1
}

pub fn (mut gb Buffer) move_cur_right() {
	if gb.cend == u64(gb.buf.len) { return }
	gb.buf[gb.ccur] = gb.buf[gb.cend]
	gb.buf[gb.cend] = 0x0
	gb.ccur += 1
	gb.cend += 1
}

fn (mut gb Buffer) grow() {
	new_size := gb.buf.len * 2
	mut copy_dst := []u8{ len: new_size, cap: new_size }
	copy(mut copy_dst, gb.buf)
	gb.buf = copy_dst
}

pub fn (gb Buffer) rawstr() string {
	return gb.buf.map(if it == 0x0 { u8(`_`) } else { it }).bytestr()
}

pub fn (gb Buffer) str() string {
	mut copy_dst := []u8{ len: gb.buf.len - int(gb.cend - gb.ccur) }
	copy(mut copy_dst[..gb.ccur], gb.buf[..gb.ccur])
	copy(mut copy_dst[gb.ccur..], gb.buf[gb.cend..])
	return copy_dst.bytestr()
}


