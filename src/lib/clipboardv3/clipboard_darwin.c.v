// Copyright 2025 The Lilly Edtior contributors
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

module clipboardv3

#include <AppKit/AppKit.h>
#flag -framework AppKit

#include "@VMODROOT/src/lib/clipboardv3/clipboard_darwin.m"

fn C.clipboard_get_plaintext() &char
fn C.clipboard_set_plaintext(text &char)
fn C.clipboard_set_content(data &char, t_type u8)
fn C.clipboard_get_content() &CClipboardContent

struct CClipboardContent {
	data &char
	t_type u8
}

struct DarwinClipboard{}

fn new_darwin_clipboard() Clipboard {
	return DarwinClipboard{}
}

fn (mut c DarwinClipboard) get_content() ?ClipboardContent {
	c_content_ptr := C.clipboard_get_content()
	if c_content_ptr == unsafe { nil } {
		return none
	}

	c_content := unsafe { &c_content_ptr }

	mut clipboard_content := ClipboardContent{
		data: ""
		type: .block // NOTE(tauraamui) [20/05/2025]: default insert mode should be block really
		             //                               cos it means its most likely coming from a non-lilly source
	}

	if c_content.data != 0 {
		clipboard_content.data = unsafe { cstring_to_vstring(c_content.data) }
		unsafe { C.free(c_content.data) }
	}

	clipboard_content.type = unsafe { ContentType(c_content.t_type) }
	if clipboard_content.type == .none { clipboard_content.type = .block }

	unsafe { C.free(c_content_ptr) }

	return clipboard_content
}

fn (mut c DarwinClipboard) set_content(content ClipboardContent) {
	C.clipboard_set_content(content.data.str, u8(content.type))
}


