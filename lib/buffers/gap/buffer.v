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

pub fn (mut b Buffer) insert(c u8) {
	// NOTE(tauraamui) [2026-06-02]: much prefer the idea the grow only occurs if next insert elapses not before
	if b.cend - b.ccur == 0 {
		b.grow()
	}
	b.buf[b.ccur] = c
	b.ccur += u64(1)
}

pub fn (mut b Buffer) delete() {
	if b.cend == u64(b.buf.len) { return }
	b.cend += 1
}

pub fn (mut b Buffer) backspace() {
	if b.ccur == 0 { return }
	b.ccur -= 1
}

pub fn (mut b Buffer) move_cur_left() {
	if b.ccur == 0 { return }
	b.ccur -= 1
	b.buf[b.cend - 1] = b.buf[b.ccur]
	b.buf[b.ccur] = 0x0
	b.cend -= 1
}

pub fn (mut b Buffer) move_cur_right() {
	if b.cend == u64(b.buf.len) { return }
	b.buf[b.ccur] = b.buf[b.cend]
	b.buf[b.cend] = 0x0
	b.ccur += 1
	b.cend += 1
}

fn (mut b Buffer) grow() {
	new_size := b.buf.len * 2
	mut copy_dst := []u8{ len: new_size, cap: new_size }
	copy(mut copy_dst, b.buf)
	b.buf = copy_dst
}

pub fn (b Buffer) rawstr() string {
	return b.buf.map(if it == 0x0 { u8(`_`) } else { it }).bytestr()
}

pub fn (b Buffer) str() string {
	mut copy_dst := []u8{ len: b.buf.len - int(b.cend - b.ccur) }
	copy(mut copy_dst[..b.ccur], b.buf[..b.ccur])
	copy(mut copy_dst[b.ccur..], b.buf[b.cend..])
	return copy_dst.bytestr()
}


