module clipboardv3

#include <AppKit/AppKit.h>
#flag -framework AppKit

#include "@VMODROOT/src/lib/clipboardv3/clipboard_darwin.m"

fn C.clipboard_get_text() &char
fn C.clipboard_set_text(text &char)
fn C.clipboard_set_content(data &char, t_type u8)
fn C.clipboard_get_content() &C.ClipboardContent

struct DarwinClipboard{}

fn new_darwin_clipboard() Clipboard {
	return DarwinClipboard{}
}

/*
fn (c DarwinClipboard) get_content() ?ClipboardContent {
	content_c_str := C.clipboard_get_text()
	if content_c_str == 0 {
		return none
	}
	content_str := unsafe { cstring_to_vstring(content_c_str) }

	return ClipboardContent{
		data: content_str
		t_type: .inline
	}
}
*/

fn (c DarwinClipboard) get_content() ?ClipboardContent {
	return none
}

fn (c DarwinClipboard) set_content(content ClipboardContent) {
	C.clipboard_set_content(content.data.str, u8(content.t_type))
}


