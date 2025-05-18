module clipboardv3

#include <AppKit/AppKit.h>
#flag -framework AppKit

#include "@VMODROOT/src/lib/clipboardv3/clipboard_darwin.m"

fn C.clipboard_get_text() &char
fn C.clipboard_set_text(text &char)

struct DarwinClipboard{}

fn new_darwin_clipboard() Clipboard {
	return DarwinClipboard{}
}

fn (c DarwinClipboard) get_content() ?ClipboardContent {
	content_c_str := C.clipboard_get_text()
	if content_c_str == 0 {
		return none
	}
	content_str := unsafe { cstring_to_vstring(content_c_str) }

	mut content := ClipboardContent{
		data: content_str
		t_type: .inline
	}
	if content.data.starts_with(block_prefix) {
		content = ClipboardContent{
			data: content.data.trim_string_left(block_prefix)
			t_type: .block
		}
	}
	return content
}

fn (c DarwinClipboard) set_content(content ClipboardContent) {
	text := if content.t_type == .block { "${block_prefix}${content.data}" } else { content.data }
	C.clipboard_set_text(&char(text.str))
}




