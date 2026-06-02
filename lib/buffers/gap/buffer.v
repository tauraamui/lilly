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
		cend: u64(size - 1)
	}
}

fn (mut b Buffer) insert(c u8) {
	b.buf[b.ccur] = c
	b.ccur += u64(1)
}

fn (b Buffer) str() string {
	mut copy_dst := []u8{ len: b.buf.len - int(b.cend - b.ccur) }
	copy(mut copy_dst[..b.ccur], b.buf[..b.ccur])
	copy(mut copy_dst[b.ccur..], b.buf[b.ccur..b.cend])
	return copy_dst.bytestr()
}


