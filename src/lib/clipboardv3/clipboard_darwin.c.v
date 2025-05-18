module clipboardv3

#include <CoreFoundation/CoreFoundation.h>
#include <ApplicationServices/ApplicationServices.h>

fn C.set_clipboard_text(const char &text_utf8)
fn C.get_clipboard_text() CFStringRef

