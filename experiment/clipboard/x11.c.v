
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

type Window = u64
type Atom   = u64

fn C.XOpenDisplay(name &u8) &C.Display

fn C.XCreateSimpleWindow(
	d &C.Display, root Window,
	x int, y int, width u32 height u32,
	border_width u32, border u64,
	background u64
) Window

fn C.RootWindow(display &C.Display, screen_number int) Window

fn main() {
	display := C.XOpenDisplay(C.NULL)
	println(display)
}

