
#import <string.h>
#import <stdlib.h>

static NSString *const ClipboardContentType = @"com.lilly.ClipboardContent";

typedef struct {
	char *data;
	unsigned char t_type;
} ClipboardContent;

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

char* clipboard_get_text(void) {
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

void clipboard_set_text(const char* text) {
	@autoreleasepool {
		if (text) {
			NSString *utf8_text = [NSString stringWithUTF8String:text];
			if (utf8_text) {
				setPasteboardTextInternal(utf8_text);
			}
		}
	}
}


