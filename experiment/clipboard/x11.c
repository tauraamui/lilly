// compile with:
// gcc x11.c -lX11

#include <X11/Xlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

#include <X11/Xatom.h>

int main(void) {
    Display* display = XOpenDisplay(NULL);
 
    Window window = XCreateSimpleWindow(display, RootWindow(display, DefaultScreen(display)), 10, 10, 200, 200, 1,
                                 BlackPixel(display, DefaultScreen(display)), WhitePixel(display, DefaultScreen(display)));
 
    XSelectInput(display, window, ExposureMask | KeyPressMask); 

	const Atom UTF8_STRING = XInternAtom(display, "UTF8_STRING", True);
	const Atom CLIPBOARD = XInternAtom(display, "CLIPBOARD", 0);
	const Atom XSEL_DATA = XInternAtom(display, "XSEL_DATA", 0);

	const Atom SAVE_TARGETS = XInternAtom((Display*) display, "SAVE_TARGETS", False);
	const Atom TARGETS = XInternAtom((Display*) display, "TARGETS", False);
	const Atom MULTIPLE = XInternAtom((Display*) display, "MULTIPLE", False);
	const Atom ATOM_PAIR = XInternAtom((Display*) display, "ATOM_PAIR", False);
	const Atom CLIPBOARD_MANAGER = XInternAtom((Display*) display, "CLIPBOARD_MANAGER", False);

	// input - read current clipboard content
	XConvertSelection(display, CLIPBOARD, UTF8_STRING, XSEL_DATA, window, CurrentTime);
	XSync(display, 0);

	XEvent event;
	XNextEvent(display, &event);

	if (event.type == SelectionNotify && event.xselection.selection == CLIPBOARD && event.xselection.property != 0) {

		int format;
		unsigned long N, size;
		char* data, * s = NULL;
		Atom target;

		XGetWindowProperty(event.xselection.display, event.xselection.requestor,
			event.xselection.property, 0L, (~0L), 0, AnyPropertyType, &target,
			&format, &size, &N, (unsigned char**) &data);

		if (target == UTF8_STRING || target == XA_STRING) {
			printf("paste: %s\n", data);
			XFree(data);
		}

		XDeleteProperty(event.xselection.display, event.xselection.requestor, event.xselection.property);
	}

	// output - set new clipboard content
	char text[] = "new string";  // removed \0 - strlen won't work correctly with it
	size_t text_len = strlen(text);

	XSetSelectionOwner((Display*) display, CLIPBOARD, (Window) window, CurrentTime);

	// Verify we actually own the selection
	if (XGetSelectionOwner(display, CLIPBOARD) != window) {
		printf("Failed to acquire clipboard ownership\n");
		XCloseDisplay(display);
		return 1;
	}

	printf("Set clipboard to: %s\n", text);
	printf("Clipboard is now available. Press Ctrl+C to exit...\n");

	// Try to save to clipboard manager
	XConvertSelection((Display*) display, CLIPBOARD_MANAGER, SAVE_TARGETS, None, (Window) window, CurrentTime);
		
	Bool running = True;
	while (running) {
		XNextEvent(display, &event);
		
		if (event.type == SelectionClear) {
			// Another application has taken ownership of the selection
			printf("Lost clipboard ownership\n");
			running = False;
		}
		else if (event.type == SelectionRequest) {
			const XSelectionRequestEvent* request = &event.xselectionrequest;

			XEvent reply = { SelectionNotify };
			reply.xselection.property = request->property;  // Default to success
			reply.xselection.display = request->display;
			reply.xselection.requestor = request->requestor;
			reply.xselection.selection = request->selection;
			reply.xselection.target = request->target;
			reply.xselection.time = request->time;

			if (request->target == TARGETS) {
				// Return list of supported formats
				const Atom targets[] = { TARGETS,
										MULTIPLE,
										UTF8_STRING,
										XA_STRING };

				XChangeProperty(display,
					request->requestor,
					request->property,
					XA_ATOM,  // Fixed: should be XA_ATOM, not 4
					32,
					PropModeReplace,
					(unsigned char*) targets,
					sizeof(targets) / sizeof(targets[0]));
			}
			else if (request->target == UTF8_STRING || request->target == XA_STRING) {
				// Return the actual text content
				XChangeProperty(display,
					request->requestor,
					request->property,
					request->target,
					8,
					PropModeReplace,
					(unsigned char*) text,
					text_len);
			}
			else if (request->target == MULTIPLE) {	
				Atom* targets = NULL;

				Atom actualType = 0;
				int actualFormat = 0;
				unsigned long count = 0, bytesAfter = 0;

				XGetWindowProperty(display, request->requestor, request->property, 0, LONG_MAX, False, ATOM_PAIR, &actualType, &actualFormat, &count, &bytesAfter, (unsigned char **) &targets);

				unsigned long i;
				for (i = 0; i < count; i += 2) {
					if (targets[i] == UTF8_STRING || targets[i] == XA_STRING) {
						XChangeProperty((Display*) display,
							request->requestor,
							targets[i + 1],
							targets[i],
							8,
							PropModeReplace,
							(unsigned char*) text,
							text_len);
					} else {
						targets[i + 1] = None;
					}
				}

				XChangeProperty((Display*) display,
					request->requestor,
					request->property,
					ATOM_PAIR,
					32,
					PropModeReplace,
					(unsigned char*) targets,
					count);

				XFree(targets);
			}
			else {
				// Unsupported target
				reply.xselection.property = None;
			}

			XSendEvent((Display*) display, request->requestor, False, 0, &reply);
			XFlush(display);
		}
		else if (event.type == KeyPress) {
			// Allow exit with any key press
			running = False;
		}
	}

	printf("Exiting...\n");
    XCloseDisplay(display);
    return 0;
}