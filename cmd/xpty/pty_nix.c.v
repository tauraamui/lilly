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

module main

import time

#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>
#include <errno.h>

$if macos {
	#include <util.h>
}
$if linux {
	#include <pty.h>
}

fn C.openpty(amaster &int, aslave &int, name &char, termp voidptr, winp voidptr) int
fn C.close(fd int) int
fn C.read(fd int, buf voidptr, count usize) isize
fn C.write(fd int, buf voidptr, count usize) isize
fn C.fork() int
fn C.setsid() int
fn C.dup2(oldfd int, newfd int) int
fn C.execvp(file &char, argv &&char) int
fn C.kill(pid int, sig int) int
fn C.fcntl(fd int, cmd int, arg ...int) int
fn C.ioctl(fd int, request u64, arg voidptr) int
fn C.strerror(errnum int) &char

struct C.winsize {
mut:
	ws_row u16
	ws_col u16
	ws_xpixel u16
	ws_ypixel u16
}

struct C.termios {
mut:
	c_iflag u32
	c_oflag u32
	c_cflag u32
	c_lflag u32
}

fn C.tcgetattr(fd int, termios_p &C.termios) int
fn C.tcsetattr(fd int, optional_actions int, termios_p &C.termios) int

fn spawn_in_pty(program string, cols u16, rows u16, golden_dir string) !(int, int) {
	mut master_fd := 0
	mut slave_fd := 0

	ws := C.winsize{
		ws_row: rows
		ws_col: cols
		ws_xpixel: 0
		ws_ypixel: 0
	}

	ret := C.openpty(&master_fd, &slave_fd, unsafe { nil }, unsafe { nil }, &ws)
	if ret < 0 {
		return error('openpty failed')
	}

	pid := C.fork()
	if pid < 0 {
		C.close(master_fd)
		C.close(slave_fd)
		return error('fork failed')
	}

	if pid == 0 {
		// Child process
		C.close(master_fd)
		C.setsid()

		// Set the slave as the controlling terminal.
		C.ioctl(slave_fd, u64(C.TIOCSCTTY), voidptr(unsafe { nil }))

		C.dup2(slave_fd, 0) // stdin
		C.dup2(slave_fd, 1) // stdout
		C.dup2(slave_fd, 2) // stderr
		if slave_fd > 2 {
			C.close(slave_fd)
		}

		// Set TERM so the child knows it has color support.
		C.setenv(c'TERM', c'xterm-256color', 1)
		// Disable telemetry for test runs.
		C.setenv(c'LILLY_NO_TELEMETRY', c'1', 1)
		// If golden frame capture is requested, tell lilly where to dump frames.
		if golden_dir.len > 0 {
			C.setenv(c'LILLY_GOLDEN_DIR', golden_dir.str, 1)
		}

		// exec the target program
		c_program := program.str
		argv := [c_program, unsafe { nil }]
		C.execvp(c_program, argv.data)

		// If we get here, exec failed.
		C._exit(127)
	}

	// Parent process
	C.close(slave_fd)

	// Set master fd to non-blocking so drain reads don't hang.
	flags := C.fcntl(master_fd, C.F_GETFL)
	C.fcntl(master_fd, C.F_SETFL, flags | C.O_NONBLOCK)

	return master_fd, pid
}

fn C.setenv(name &char, value &char, overwrite int) int
fn C._exit(status int)

fn drain_pty(fd int, timeout_ms int) []u8 {
	mut buf := []u8{len: 65536}
	mut result := []u8{}
	deadline := time.now().add(timeout_ms * time.millisecond)

	for time.now() < deadline {
		n := C.read(fd, buf.data, usize(buf.len))
		if n > 0 {
			result << buf[..int(n)]
			// Keep reading while data is available.
			continue
		}
		// EAGAIN/EWOULDBLOCK means no data right now on non-blocking fd.
		time.sleep(10 * time.millisecond)
	}
	return result
}

fn write_to_fd(fd int, data []u8) {
	mut written := 0
	for written < data.len {
		n := C.write(fd, unsafe { &u8(data.data) + written }, usize(data.len - written))
		if n < 0 {
			break
		}
		written += int(n)
	}
}
