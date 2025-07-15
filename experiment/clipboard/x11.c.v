#flag -lX11

#include <X11/Xlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <X11/Xatom.h>

@[typedef]
pub struct C.Display {}

fn (d &C.Display) str() string {
	return 'C.Display{}'
}

@[typedef]
pub struct C.XSelectionEvent {
mut:
	type      int
	display   &C.Display = unsafe { nil }
	requestor Window
	selection Atom
	target    Atom
	property  Atom
	time      int
}

type Window = u64
type Atom = u64
type EventMask = u64

fn C.XOpenDisplay(name &u8) &C.Display

fn C.XCloseDisplay(d &C.Display)

fn C.XFlush(display &C.Display)

fn C.XNextEvent(display &C.Display, event &C.XEvent)

fn C.XSetSelectionOwner(display &C.Display, atom Atom, window Window, time int)

fn C.XCreateSimpleWindow(d &C.Display, root Window,
	x int, y int, width u32, height u32,
	border_width u32, border u64,
	background u64) Window

fn C.XSelectInput(d &C.Display, window Window, EventMask)

fn C.XInternAtom(display &C.Display, atom_name &u8, only_if_exists int) Atom

fn C.XConvertSelection(display &C.Display, selection Atom, target Atom, property Atom, requestor Window, time int) int

fn C.XSync(display &C.Display, discard int) int

fn C.XGetWindowProperty(display &C.Display, window Window,
	property Atom, long_offset i64, long_length i64,
	delete int, req_type Atom, actual_type_return &Atom,
	actual_format_return &int, nitems_return &u64,
	bytes_after_return &u64, prop_return &&u8) int

fn C.XChangeProperty(display &C.Display,
	window Window,
	property Atom,
	typ Atom,
	format int,
	mode int,
	data voidptr,
	nelements int) int

fn C.XSendEvent(display &C.Display, requestor Window, propegate int, mask i64, event &C.XEvent)

fn C.RootWindow(display &C.Display, screen_number int) Window

fn C.XDeleteProperty(display &C.Display, window Window, property Atom) int

fn C.DefaultScreen(display &C.Display) int

fn C.BlackPixel(display &C.Display, screen_number int) u32

fn C.WhitePixel(display &C.Display, screen_number int) u32

fn C.XFree(data voidptr)

@[typedef]
pub struct C.XSelectionRequestEvent {
mut:
	display   &C.Display = unsafe { nil }
	owner     Window
	requestor Window
	selection Atom
	target    Atom
	property  Atom
	time      int
}

@[typedef]
pub struct C.XSelectionEvent {
mut:
	type      int
	display   &C.Display = unsafe { nil }
	requestor Window
	selection Atom
	target    Atom
	property  Atom
	time      int
}

@[typedef]
pub struct C.XSelectionClearEvent {
mut:
	window    Window
	selection Atom
}

@[typedef]
pub struct C.XDestroyWindowEvent {
mut:
	window Window
}

@[typedef]
union C.XEvent {
mut:
	type              int
	xdestroywindow    C.XDestroyWindowEvent
	xselectionclear   C.XSelectionClearEvent
	xselectionrequest C.XSelectionRequestEvent
	xselection        C.XSelectionEvent
}

fn main() {
	display := C.XOpenDisplay(C.NULL)
	defer { C.XCloseDisplay(display) }

	window := C.XCreateSimpleWindow(display, C.RootWindow(display, C.DefaultScreen(display)),
		10, 10, 200, 200, 1, C.BlackPixel(display, C.DefaultScreen(display)), C.WhitePixel(display,
		C.DefaultScreen(display)))

	C.XSelectInput(display, window, C.ExposureMask | C.KeyPressMask)

	utf8_string := C.XInternAtom(display, &char(c'UTF8_STRING'), 1)
	clipboard := C.XInternAtom(display, &char(c'CLIPBOARD'), 0)
	xsel_data := C.XInternAtom(display, &char(c'XSEL_DATA'), 0)

	save_targets := C.XInternAtom(display, &char(c'SAVE_TARGETS'), 0)
	targets := C.XInternAtom(display, &char(c'TARGETS'), 0)
	multiple := C.XInternAtom(display, &char(c'MULTIPLE'), 0)
	atom_pair := C.XInternAtom(display, &char(c'ATOM_PAIR'), 0)
	clipboard_manager := C.XInternAtom(display, &char(c'CLIPBOARD_MANAGER'), 0)

	C.XConvertSelection(display, clipboard, utf8_string, xsel_data, window, C.CurrentTime)
	C.XSync(display, 0)

	event := C.XEvent{}
	C.XNextEvent(display, &event)

	xa_string := Atom(31)
	if unsafe {
		event.type == C.SelectionNotify && event.xselection.selection == clipboard
			&& event.xselection.property != 0
	} {
		format := 0
		n := u64(0)
		size := u64(0)
		data := &u8(unsafe { nil })
		target := Atom(0)

		C.XGetWindowProperty(event.xselection.display, event.xselection.requestor, event.xselection.property,
			0, 1024, 0, C.AnyPropertyType, &target, &format, &size, &n, &data)

		if target == utf8_string || target == xa_string {
			println('CURRENT CLIPBOARD CONTENT: ${cstring_to_vstring(data)}')
			C.XFree(data)
		}

		C.XDeleteProperty(event.xselection.display, event.xselection.requestor, event.xselection.property)
	}

	text_to_insert_to_clipboard := 'an example string to copy'

	C.XSetSelectionOwner(display, clipboard, window, C.CurrentTime)
	C.XConvertSelection(display, clipboard_manager, save_targets, C.None, window, C.CurrentTime)

	mut running := true
	for running {
		C.XNextEvent(display, &event)
		if unsafe { event.type == C.SelectionRequest } {
			request := unsafe { &event.xselectionrequest }

			mut reply := C.XEvent{
				type: C.SelectionNotify
			}
			reply.xselection = C.XSelectionEvent{
				property: Atom(0)
			}

			if request.target == targets {
				target_atoms := [targets, multiple, utf8_string, xa_string]
				C.XChangeProperty(display, request.requestor, request.property, Atom(4),
					Atom(32), C.PropModeReplace, target_atoms.data, target_atoms.len / int(sizeof(target_atoms[0])))

				reply.xselection.property = request.property
			}

			if request.target == multiple {
				mut target_atoms := []Atom{}

				actual_type := Atom(0)
				actual_format := 0
				count := u64(0)
				bytes_after := u64(0)

				C.XGetWindowProperty(display, request.requestor, request.property, 0,
					C.LONG_MAX, 0, atom_pair, &actual_type, &actual_format, &count, &bytes_after,
					target_atoms.data)

				for i := 0; i < count; i += 2 {
					if target_atoms[i] == utf8_string || target_atoms[i] == xa_string {
						C.XChangeProperty(display, request.requestor, target_atoms[i + 1],
							target_atoms[i], Atom(8), C.PropModeReplace, text_to_insert_to_clipboard.str,
							text_to_insert_to_clipboard.len)
						C.XFlush(display)
						running = false
						continue
					}
					target_atoms[i + 1] = C.None
				}

				C.XChangeProperty(display, request.requestor, request.property, atom_pair,
					Atom(32), C.PropModeReplace, target_atoms.data, count)
				C.XFlush(display)
				C.XFree(voidptr(&target_atoms))

				reply.xselection.property = request.property
			}

			reply.xselection.display = request.display
			reply.xselection.requestor = request.requestor
			reply.xselection.selection = request.selection
			reply.xselection.target = request.target
			reply.xselection.time = request.time

			C.XSendEvent(display, request.requestor, 0, 0, voidptr(&reply))
			C.XFlush(display)
		}
	}
}
