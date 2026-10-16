// Copyright 2026 The Lilly Editor contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

module pty

#flag -I @VMODROOT/lib/pty
#include "conpty.h"

struct C.lilly_conpty {
	hpc      voidptr
	in_write voidptr
	out_read voidptr
	process  voidptr
}

fn C.lilly_conpty_spawn(p &C.lilly_conpty, cmdline &u16, cols i16, rows i16) int
fn C.lilly_conpty_read(p &C.lilly_conpty, buf &u8, len int) int
fn C.lilly_conpty_write(p &C.lilly_conpty, buf &u8, len int) int
fn C.lilly_conpty_resize(p &C.lilly_conpty, cols i16, rows i16)
fn C.lilly_conpty_poll(p &C.lilly_conpty, code &int) int
fn C.lilly_conpty_close(p &C.lilly_conpty, terminate int)

@[heap]
pub struct Process {
mut:
	con    C.lilly_conpty
	status ?ExitStatus
	closed bool
}

// spawn starts argv in a new pseudo console of the given size
pub fn spawn(argv []string, cols u16, rows u16) !&Process {
	if argv.len == 0 {
		return error('nothing to run')
	}
	mut p := &Process{}
	cmdline := argv.map(quote_arg(it)).join(' ')
	rc := C.lilly_conpty_spawn(&p.con, cmdline.to_wide(), i16(cols), i16(rows))
	if rc != 0 {
		return error('could not start ${argv[0]} in a pseudo console (step ${-rc})')
	}
	return p
}

// quote_arg quotes an argument the way CommandLineToArgvW splits them back
fn quote_arg(arg string) string {
	if arg.len > 0 && !arg.contains_any(' \t"') {
		return arg
	}
	mut out := '"'
	mut backslashes := 0
	for ch in arg {
		if ch == `\\` {
			backslashes++
			continue
		}
		if ch == `"` {
			out += '\\'.repeat(backslashes * 2 + 1) + '"'
			backslashes = 0
			continue
		}
		out += '\\'.repeat(backslashes) + ch.ascii_str()
		backslashes = 0
	}
	return out + '\\'.repeat(backslashes * 2) + '"'
}

// read returns everything the child has drawn since the last call, without
// waiting for more
pub fn (mut p Process) read() []u8 {
	mut out := []u8{}
	mut buf := []u8{len: 65536}
	for {
		n := C.lilly_conpty_read(&p.con, buf.data, buf.len)
		if n <= 0 {
			return out
		}
		out << buf[..n]
	}
	return out
}

// write sends data as typed input
pub fn (mut p Process) write(data []u8) ! {
	mut written := 0
	for written < data.len {
		n := C.lilly_conpty_write(&p.con, unsafe { &u8(data.data) + written }, data.len - written)
		if n <= 0 {
			return error('child stopped reading input')
		}
		written += n
	}
}

// resize changes the pseudo console's size, which the child sees as a
// window buffer size event
pub fn (mut p Process) resize(cols u16, rows u16) {
	C.lilly_conpty_resize(&p.con, i16(cols), i16(rows))
}

// exited reports how the child ended, or none while it is still running
pub fn (mut p Process) exited() ?ExitStatus {
	if s := p.status {
		return s
	}
	mut code := 0
	if C.lilly_conpty_poll(&p.con, &code) == 0 {
		return none
	}
	s := ExitStatus{
		code: code
	}
	p.status = s
	return s
}

// stacks would describe where a running child's threads are. Nothing
// collects them on Windows yet.
pub fn (p &Process) stacks() string {
	return ''
}

// kill ends the child if it is still running, and releases the console
pub fn (mut p Process) kill() {
	if p.closed {
		return
	}
	running := p.exited() == none
	C.lilly_conpty_close(&p.con, int(running))
	p.closed = true
}
