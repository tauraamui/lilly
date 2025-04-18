module utf8

pub fn str_visible_length(s string) int {
	mut l := 0
	mut ul := 1
	for i := 0; i < s.len; i += ul {
		c := unsafe { s.str[i] }
		ul = ((0xe5000000 >> ((unsafe { s.str[i] } >> 3) & 0x1e)) & 3) + 1
		if i + ul > s.len { // incomplete UTF-8 sequence
			return l
		}
		l++
		// avoid the match if not needed
		if ul == 1 {
			continue
		}
		// recognize combining characters and wide characters
		match ul {
			2 {
				r := u64((u16(c) << 8) | unsafe { s.str[i + 1] })
				if r >= 0xcc80 && r < 0xcdb0 {
					// diacritical marks
					l--
				}
			}
			3 {
				r := u64((u32(c) << 16) | unsafe { (u32(s.str[i + 1]) << 8) | s.str[i + 2] })
				// diacritical marks extended
				// diacritical marks supplement
				// diacritical marks for symbols
				if (r >= 0xe1aab0 && r <= 0xe1ac7f)
					|| (r >= 0xe1b780 && r <= 0xe1b87f)
					|| (r >= 0xe28390 && r <= 0xe2847f)
					|| (r >= 0xefb8a0 && r <= 0xefb8af) {
					// diacritical marks
					l--
				}
				// Hangru
				// CJK Unified Ideographics
				// Hangru
				// CJK
				else if (r >= 0xe18480 && r <= 0xe1859f)
					|| (r >= 0xe2ba80 && r <= 0xe2bf95)
					|| (r >= 0xe38080 && r <= 0xe4b77f)
					|| (r >= 0xe4b880 && r <= 0xea807f)
					|| (r >= 0xeaa5a0 && r <= 0xeaa79f)
					|| (r >= 0xeab080 && r <= 0xed9eaf)
					|| (r >= 0xefa480 && r <= 0xefac7f)
					|| (r >= 0xefb8b8 && r <= 0xefb9af) {
					// half marks
					l++
				}
			}
			4 {
				r := u64((u32(c) << 24) | unsafe {
					(u32(s.str[i + 1]) << 16) | (u32(s.str[i + 2]) << 8) | s.str[i + 3]
				})
				// Enclosed Ideographic Supplement
				// Emoji
				// CJK Unified Ideographs Extension B-G
				if (r >= 0x0f9f8880 && r <= 0xf09f8a8f)
					|| (r >= 0xf09f8c80 && r <= 0xf09f9c90)
					|| (r >= 0xf09fa490 && r <= 0xf09fa7af)
					|| (r >= 0xf0a08080 && r <= 0xf180807f) {
					l++
				}
			}
			else {}
		}
	}
	return l
}
