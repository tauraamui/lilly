// compile with:
// gcc x11.c -lX11

#include <X11/Xlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <unistd.h>

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
	char text[] = "new string";
	size_t text_len = strlen(text);

	XSetSelectionOwner((Display*) display, CLIPBOARD, (Window) window, CurrentTime);

	// Verify we actually own the selection
	if (XGetSelectionOwner(display, CLIPBOARD) != window) {
		printf("Failed to acquire clipboard ownership\n");
		XCloseDisplay(display);
		return 1;
	}

	printf("Set clipboard to: %s\n", text);
	printf("Clipboard is now available. Press any key to exit and transfer to clipboard manager...\n");

	Bool running = True;
	Bool exit_requested = False;
	Bool clipboard_manager_notified = False;
	Bool waiting_for_manager = False;

	while (running) {
		// Check if we have pending events
		if (XPending(display) > 0) {
			XNextEvent(display, &event);
		} else if (exit_requested && !waiting_for_manager) {
			// No more events and exit was requested, try to notify clipboard manager
			Window clipboard_manager_window = XGetSelectionOwner(display, CLIPBOARD_MANAGER);
			
			if (clipboard_manager_window != None) {
				printf("Transferring clipboard to manager...\n");
				
				// Send SAVE_TARGETS request to clipboard manager
				XConvertSelection(display, CLIPBOARD_MANAGER, SAVE_TARGETS, None, window, CurrentTime);
				XFlush(display);
				waiting_for_manager = True;
				
				// Set a timeout - don't wait forever for clipboard manager
				alarm(2);
			} else {
				printf("No clipboard manager found - clipboard will be lost\n");
				running = False;
			}
		} else if (!XPending(display)) {
			// No events pending, sleep briefly to avoid busy waiting
			usleep(10000); // 10ms
			continue;
		}

		if (XPending(display) > 0) {
			XNextEvent(display, &event);
		} else {
			continue;
		}
		
		if (event.type == SelectionClear) {
			printf("Lost clipboard ownership to another application\n");
			running = False;
		}
		else if (event.type == SelectionNotify) {
			// Response from clipboard manager
			if (event.xselection.selection == CLIPBOARD_MANAGER) {
				if (event.xselection.property != None) {
					printf("Clipboard manager acknowledged transfer\n");
				} else {
					printf("Clipboard manager failed to save clipboard\n");
				}
				running = False;
			}
		}
		else if (event.type == SelectionRequest) {
			const XSelectionRequestEvent* request = &event.xselectionrequest;

			XEvent reply = { SelectionNotify };
			reply.xselection.property = request->property;
			reply.xselection.display = request->display;
			reply.xselection.requestor = request->requestor;
			reply.xselection.selection = request->selection;
			reply.xselection.target = request->target;
			reply.xselection.time = request->time;

			Bool handled = True;

			if (request->target == TARGETS) {
				// Return list of supported formats
				const Atom targets[] = { TARGETS,
										MULTIPLE,
										UTF8_STRING,
										XA_STRING };

				XChangeProperty(display,
					request->requestor,
					request->property,
					XA_ATOM,
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

				if (targets && count > 0) {
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
			}
			else {
				// Unsupported target
				reply.xselection.property = None;
				handled = False;
			}

			XSendEvent((Display*) display, request->requestor, False, 0, &reply);
			XFlush(display);

			if (handled) {
				printf("Served clipboard request for target: %s\n", 
					   request->target == UTF8_STRING ? "UTF8_STRING" :
					   request->target == XA_STRING ? "XA_STRING" :
					   request->target == TARGETS ? "TARGETS" :
					   request->target == MULTIPLE ? "MULTIPLE" : "UNKNOWN");
			}
		}
		else if (event.type == KeyPress) {
			// Request exit - will trigger clipboard manager transfer
			if (!exit_requested) {
				exit_requested = True;
				printf("Exit requested, attempting to transfer to clipboard manager...\n");
			}
		}
	}

	printf("Exiting...\n");
	alarm(0); // Cancel any pending alarm
    XCloseDisplay(display);
    return 0;
}