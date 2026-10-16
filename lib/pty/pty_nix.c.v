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

import time

#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/wait.h>

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
fn C.waitpid(pid int, wstatus &int, options int) int
fn C.fcntl(fd int, cmd int, arg ...int) int
fn C.ioctl(fd int, request u64, arg ...voidptr) int
fn C._exit(status int)
fn C.WIFEXITED(status int) bool
fn C.WEXITSTATUS(status int) int
fn C.WIFSIGNALED(status int) bool
fn C.WTERMSIG(status int) int

struct C.winsize {
mut:
	ws_row    u16
	ws_col    u16
	ws_xpixel u16
	ws_ypixel u16
}

// how long write keeps retrying a full pty before deciding the child has
// stopped reading its input
const write_stall_timeout = 10 * time.second

@[heap]
pub struct Process {
pub:
	pid int
mut:
	fd      int
	pending []u8
	status  ?ExitStatus
}

// spawn starts argv in a new pty of the given size, as the leader of its own
// session, so kill takes any process it started down with it
pub fn spawn(argv []string, cols u16, rows u16) !&Process {
	if argv.len == 0 {
		return error('nothing to run')
	}
	mut master_fd := 0
	mut slave_fd := 0
	ws := C.winsize{
		ws_row: rows
		ws_col: cols
	}
	if C.openpty(&master_fd, &slave_fd, unsafe { nil }, unsafe { nil }, &ws) < 0 {
		return error('openpty failed')
	}

	// argv is built before the fork: the child must not allocate
	mut c_argv := unsafe { []&char{len: argv.len + 1} }
	for i, arg in argv {
		c_argv[i] = &char(arg.str)
	}
	c_argv[argv.len] = unsafe { nil }

	pid := C.fork()
	if pid < 0 {
		C.close(master_fd)
		C.close(slave_fd)
		return error('fork failed')
	}
	if pid == 0 {
		C.close(master_fd)
		C.setsid()
		C.ioctl(slave_fd, u64(C.TIOCSCTTY), voidptr(unsafe { nil }))
		C.dup2(slave_fd, 0)
		C.dup2(slave_fd, 1)
		C.dup2(slave_fd, 2)
		if slave_fd > 2 {
			C.close(slave_fd)
		}
		C.execvp(c_argv[0], c_argv.data)
		C._exit(127)
	}

	C.close(slave_fd)
	flags := C.fcntl(master_fd, C.F_GETFL)
	C.fcntl(master_fd, C.F_SETFL, flags | C.O_NONBLOCK)
	return &Process{
		pid: pid
		fd:  master_fd
	}
}

// read returns everything the child has drawn since the last call, without
// waiting for more
pub fn (mut p Process) read() []u8 {
	p.fill()
	out := p.pending.clone()
	p.pending.clear()
	return out
}

fn (mut p Process) fill() {
	mut buf := []u8{len: 65536}
	for {
		n := C.read(p.fd, buf.data, usize(buf.len))
		if n <= 0 {
			return
		}
		p.pending << buf[..int(n)]
	}
}

// write sends data as typed input. While the pty is full it keeps draining
// the child's output, so a child blocked on drawing is never mistaken for one
// that stopped reading, and fails only once the input has not moved at all
// for write_stall_timeout.
pub fn (mut p Process) write(data []u8) ! {
	mut written := 0
	mut last_progress := time.now()
	for written < data.len {
		n := C.write(p.fd, unsafe { &u8(data.data) + written }, usize(data.len - written))
		if n > 0 {
			written += int(n)
			last_progress = time.now()
			continue
		}
		if n < 0 && C.errno != C.EAGAIN && C.errno != C.EWOULDBLOCK {
			return error('write to pty failed (errno ${C.errno})')
		}
		if time.since(last_progress) > write_stall_timeout {
			return error('child stopped reading input')
		}
		p.fill()
		time.sleep(5 * time.millisecond)
	}
}

// resize changes the pty's size, which delivers SIGWINCH to the child
pub fn (mut p Process) resize(cols u16, rows u16) {
	ws := C.winsize{
		ws_row: rows
		ws_col: cols
	}
	C.ioctl(p.fd, u64(C.TIOCSWINSZ), &ws)
}

// exited reports how the child ended, or none while it is still running
pub fn (mut p Process) exited() ?ExitStatus {
	if s := p.status {
		return s
	}
	mut status := 0
	if C.waitpid(p.pid, &status, C.WNOHANG) != p.pid {
		return none
	}
	s := if C.WIFSIGNALED(status) {
		ExitStatus{
			signal: C.WTERMSIG(status)
		}
	} else {
		ExitStatus{
			code: C.WEXITSTATUS(status)
		}
	}
	p.status = s
	return s
}

// kill ends the child and everything in its session, and releases the pty
pub fn (mut p Process) kill() {
	// the session even when the child has exited: whatever it started, a git
	// query say, can still be running
	C.kill(-p.pid, C.SIGKILL)
	defer {
		C.close(p.fd)
	}
	if _ := p.exited() {
		return
	}
	C.kill(p.pid, C.SIGKILL)
	mut status := 0
	C.waitpid(p.pid, &status, 0)
	p.status = ExitStatus{
		signal: C.SIGKILL
	}
}
