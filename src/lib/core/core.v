module core

import os

pub fn is_binary_file(path string) !bool {
	mut f := os.open(path) or { return error("is_binary_file: unable to open ${path}: ${err}") }
	mut buf := []u8{ len: 1024 }
	bytes_read := f.read_bytes_into(0, mut buf) or { return error("is_binary_file: failed to read bytes into memory: ${err}") }

	mut non_text_bytes := 0
	for i in 0..bytes_read {
		b := buf[i]
		// count bytes outside printable ASCII range
		if (b < 32 && b != 9 && b != 10 && b != 13) || b > 126 {
			non_text_bytes += 1
		}
	}

	// if more than 30% of read bytes are non-text, consider it to be a binary file
	return (f64(non_text_bytes) / f64(bytes_read)) > 0.3
}
