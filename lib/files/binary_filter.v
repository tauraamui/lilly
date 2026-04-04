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

module files

import os

// Magic number signatures for known binary file formats.
// Each entry is a byte sequence that appears at the start of the file.
const binary_magic_numbers = [
	// Executables
	[u8(0x7f), 0x45, 0x4c, 0x46], // ELF
	[u8(0x4d), 0x5a], // PE/MZ (Windows exe/dll)
	[u8(0xfe), 0xed, 0xfa, 0xce], // Mach-O 32-bit
	[u8(0xfe), 0xed, 0xfa, 0xcf], // Mach-O 64-bit
	[u8(0xce), 0xfa, 0xed, 0xfe], // Mach-O 32-bit (reversed)
	[u8(0xcf), 0xfa, 0xed, 0xfe], // Mach-O 64-bit (reversed)
	// Java
	[u8(0xca), 0xfe, 0xba, 0xbe], // Java class file
	// Images
	[u8(0x89), 0x50, 0x4e, 0x47], // PNG
	[u8(0xff), 0xd8, 0xff], // JPEG
	[u8(0x47), 0x49, 0x46, 0x38, 0x37, 0x61], // GIF87a
	[u8(0x47), 0x49, 0x46, 0x38, 0x39, 0x61], // GIF89a
	[u8(0x42), 0x4d], // BMP
	[u8(0x49), 0x49, 0x2a, 0x00], // TIFF (little-endian)
	[u8(0x4d), 0x4d, 0x00, 0x2a], // TIFF (big-endian)
	[u8(0x00), 0x00, 0x01, 0x00], // ICO
	[u8(0x52), 0x49, 0x46, 0x46], // WEBP (RIFF container)
	// Archives
	[u8(0x50), 0x4b, 0x03, 0x04], // ZIP/JAR/DOCX/etc
	[u8(0x50), 0x4b, 0x05, 0x06], // ZIP (empty archive)
	[u8(0x50), 0x4b, 0x07, 0x08], // ZIP (spanned archive)
	[u8(0x1f), 0x8b], // GZIP
	[u8(0x42), 0x5a, 0x68], // BZ2
	[u8(0x37), 0x7a, 0xbc, 0xaf, 0x27, 0x1c], // 7z
	[u8(0xfd), 0x37, 0x7a, 0x58, 0x5a, 0x00], // XZ
	[u8(0x28), 0xb5, 0x2f, 0xfd], // Zstandard
	// Documents/Media
	[u8(0x25), 0x50, 0x44, 0x46], // PDF
	[u8(0x00), 0x00, 0x00], // Various media containers (MP4/MOV ftyp at offset 4, but leading zeros are a strong non-text signal)
	// Audio
	[u8(0x49), 0x44, 0x33], // MP3 (ID3)
	[u8(0x66), 0x4c, 0x61, 0x43], // FLAC
	[u8(0x4f), 0x67, 0x67, 0x53], // OGG
	// Database
	[u8(0x53), 0x51, 0x4c, 0x69, 0x74, 0x65], // SQLite
	// WebAssembly
	[u8(0x00), 0x61, 0x73, 0x6d], // WASM
	// Object/Library archives
	[u8(0x21), 0x3c, 0x61, 0x72, 0x63, 0x68, 0x3e], // ar archive (static libraries .a)
	// LLVM
	[u8(0x42), 0x43, 0xc0, 0xde], // LLVM bitcode
]

const max_header_len = 8

// is_binary checks whether a file's header matches a known binary format.
// Returns true if the file starts with a recognized binary magic number.
// Returns false if no known binary signature is found (assumed to be text).
// Also returns false for files that cannot be read.
pub fn is_binary(path string) bool {
	mut f := os.open(path) or { return false }
	defer {
		f.close()
	}
	mut buf := []u8{len: max_header_len}
	bytes_read := f.read(mut buf) or { return false }
	if bytes_read == 0 {
		return false
	}
	for magic in binary_magic_numbers {
		if bytes_read >= magic.len && buf[..magic.len] == magic {
			return true
		}
	}
	return false
}
