
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
union C.XEvent {
mut:
	type int
	xselection C.XSelectionEvent
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

type Window    = u64
type Atom      = u64
type EventMask = u64

fn C.XOpenDisplay(name &u8) &C.Display

fn C.XCloseDisplay(d &C.Display)

fn C.XNextEvent(display &C.Display, event &C.XEvent)

fn C.XCreateSimpleWindow(
	d &C.Display, root Window,
	x int, y int, width u32 height u32,
	border_width u32, border u64,
	background u64
) Window

fn C.XSelectInput(d &C.Display, window Window, EventMask)

fn C.XInternAtom(display &C.Display, atom_name &u8, only_if_exists int) Atom

fn C.XConvertSelection(display &C.Display, selection Atom, target Atom, property Atom, requestor Window, time int) int

fn C.XSync(display &C.Display, discard int) int

fn C.XGetWindowProperty(
	display &C.Display, window Window,
	property Atom, long_offset i64, long_length i64,
	delete int, req_type Atom, actual_type_return &Atom,
	actual_format_return &int, nitems_return &u64,
	bytes_after_return &u64, prop_return &&u8
) int

fn C.RootWindow(display &C.Display, screen_number int) Window

fn C.DefaultScreen(display &C.Display) int

fn C.BlackPixel(display &C.Display, screen_number int) u32

fn C.WhitePixel(display &C.Display, screen_number int) u32

fn C.XFree(data voidptr)

fn main() {
	display := C.XOpenDisplay(C.NULL)
	defer { C.XCloseDisplay(display) }

	window := C.XCreateSimpleWindow(
		display, C.RootWindow(display, C.DefaultScreen(display)),
		10, 10, 200, 200, 1,
		C.BlackPixel(display, C.DefaultScreen(display)), C.WhitePixel(display, C.DefaultScreen(display))
	)

	C.XSelectInput(display, window, C.ExposureMask | C.KeyPressMask)

	utf8_string := C.XInternAtom(display, &char("UTF8_STRING".str), 1)
	clipboard   := C.XInternAtom(display, &char("CLIPBOARD".str), 0)
	xsel_data   := C.XInternAtom(display, &char("XSEL_DATA".str), 0)

	save_targets      := C.XInternAtom(display, &char("SAVE_TARGETS".str), 0)
	targets           := C.XInternAtom(display, &char("TARGETS".str), 0)
	multiple          := C.XInternAtom(display, &char("MULTIPLE".str), 0)
	atom_pair         := C.XInternAtom(display, &char("ATOM_PAIR".str), 0)
	clipboard_manager := C.XInternAtom(display, &char("CLIPBOARD_MANAGER".str), 0)

	C.XConvertSelection(display, clipboard, utf8_string, xsel_data, window, C.CurrentTime)
	C.XSync(display, 0)

	event := C.XEvent{}
	C.XNextEvent(display, &event)

	if event.type == C.SelectionNotify && event.xselection.selection == clipboard && event.xselection.property != 0 {
		format := 0
		n      := u64(0)
		size   := u64(0)
		data   := &u8(unsafe { nil })
		target := Atom(0)

		C.XGetWindowProperty(
			event.xselection.display, event.xselection.requestor,
			event.xselection.property, 0, 1024, 0, C.AnyPropertyType,
			&target, &format, &size, &n, &data
		)

		xa_string := Atom(31)
		if target == utf8_string || target == xa_string {
			println("CURRENT CLIPBOARD CONTENT: ${cstring_to_vstring(data)}")
			C.XFree(data)
		}
	}
}

