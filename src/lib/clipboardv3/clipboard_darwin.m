
void set_clipboard_text(const char *text_utf8) {
	PasteboardRef pasteboard;
	OSStatus status;

	status = PasteboardCreate(kPasteboardDrawingToList, &pasteboard);
	if (status != noErr) {
	}
}

