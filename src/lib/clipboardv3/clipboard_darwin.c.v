module clipboardv3

#include <AppKit/AppKit.h>
#flag -framework AppKit

#include "@VMODROOT/src/lib/clipboardv3/clipboard_darwin.m"

fn C.clipboard_get_text() &char
fn C.clipboard_set_text(text &char)
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

fn (c DarwinClipboard) get_content() ?ClipboardContent {
	c_content_ptr := C.clipboard_get_content()
	if c_content_ptr == unsafe { nil } {
		return none
	}

	c_content := unsafe { &c_content_ptr }

	mut clipboard_content := ClipboardContent{
		data: ""
		t_type: .none
	}

	if c_content.data != 0 {
		clipboard_content.data = unsafe { cstring_to_vstring(c_content.data) }
		unsafe { C.free(c_content.data) }
	}

	clipboard_content.t_type = unsafe { ContentType(c_content.t_type) }

	unsafe { C.free(c_content_ptr) }

	return clipboard_content
}

fn (c DarwinClipboard) set_content(content ClipboardContent) {
	C.clipboard_set_content(content.data.str, u8(content.t_type))
}


