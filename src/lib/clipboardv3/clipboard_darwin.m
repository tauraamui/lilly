
#import <string.h>
#import <stdlib.h>

static NSString *const ClipboardContentType = @"com.lilly.ClipboardContent";

static NSString *getPasteboardTextInternal(void) {
	NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
	NSString *text = [pasteboard stringForType:NSPasteboardTypeString];
	return text;
}

static void setPasteboardTextInternal(NSString *text) {
	if (text) {
		NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
		[pasteboard clearContents];
		[pasteboard setString:text forType:NSPasteboardTypeString];
	}
}

src__lib__clipboardv3__CClipboardContent* clipboard_get_content(void) {
	src__lib__clipboardv3__CClipboardContent* clipboard_content = NULL;
	@autoreleasepool {
		NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];

		NSData *archivedData = [pasteboard dataForType:ClipboardContentType];
		if (archivedData) {
			NSError *error = nil;
			NSDictionary *contentDict = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSString class], [NSNumber class], nil] fromData:archivedData error:&error];

			if (contentDict && !error && [contentDict isKindOfClass:[NSDictionary class]]) {
				NSString *text = contentDict[@"data"];
				NSNumber *t_type = contentDict[@"type"];

				if (text && t_type) {
					clipboard_content = malloc(sizeof(src__lib__clipboardv3__CClipboardContent));
					if (clipboard_content) {
						clipboard_content->data = NULL;
						const char *utf8String = [text UTF8String];
						if (utf8String) {
							clipboard_content->data = malloc(strlen(utf8String) + 1);
							if (clipboard_content->data) {
								strcpy(clipboard_content->data, utf8String);
								clipboard_content->t_type = [t_type unsignedCharValue];
							} else {
								free(clipboard_content);
								clipboard_content = NULL;
							}
						} else {
							free(clipboard_content);
							clipboard_content = NULL;
						}
					} else {
						clipboard_content = NULL;
					}
				}
			}
			return clipboard_content;
		}

		NSString *plainText = getPasteboardTextInternal();
		if (plainText) {
			clipboard_content = malloc(sizeof(src__lib__clipboardv3__CClipboardContent));
			if (clipboard_content) {
				clipboard_content->data = NULL;
				const char *utf8String = [plainText UTF8String];
				if (utf8String) {
					clipboard_content->data = malloc(strlen(utf8String) + 1);
					if (clipboard_content->data) {
						strcpy(clipboard_content->data, utf8String);
						clipboard_content->t_type = 0;
					} else {
						free(clipboard_content);
						clipboard_content = NULL;
					}
				} else {
					free(clipboard_content);
					clipboard_content = NULL;
				}
			} else {
				clipboard_content = NULL;
			}
		}
		return clipboard_content;
	}
}

void clipboard_set_content(const char* data, unsigned char contentType) {
	@autoreleasepool {
		if (!data) {
			return;
		}
		NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
		[pasteboard clearContents];

		NSMutableDictionary *contentDict = [NSMutableDictionary dictionary];

		NSString *textString = [NSString stringWithUTF8String:data];
		if (textString) {
			[contentDict setObject:textString forKey:@"data"];
		}

		[contentDict setObject:@(contentType) forKey:@"type"];

		NSError *error = nil;
		NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject:contentDict requiringSecureCoding:NO error:&error];

		if (archivedData && !error) {
			[pasteboard setData:archivedData forType:ClipboardContentType];
			if (textString) {
				[pasteboard setString:textString forType:NSPasteboardTypeString];
			}
		}
	}
}

char* clipboard_get_plaintext(void) {
	char* text = NULL;
	@autoreleasepool {
		NSString *clipboard_text = getPasteboardTextInternal();
		if (clipboard_text) {
			const char *utf8_clipboard_text = [clipboard_text UTF8String];
			if (utf8_clipboard_text) {
				text = malloc(strlen(utf8_clipboard_text) + 1);
				if (text) {
					strcpy(text, utf8_clipboard_text);
				}
			}
		}
	}
	return text;
}

void clipboard_set_plaintext(const char* text) {
	@autoreleasepool {
		if (text) {
			NSString *utf8_text = [NSString stringWithUTF8String:text];
			if (utf8_text) {
				setPasteboardTextInternal(utf8_text);
			}
		}
	}
}


