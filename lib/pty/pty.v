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

// Package pty runs a program inside a pseudo terminal: openpty on Linux and
// macOS, ConPTY on Windows. Both backends share one API, so a harness that
// drives lilly through it runs unchanged on every platform lilly ships for.
//
// The environment is inherited, so set anything the child needs with
// os.setenv before calling spawn.
module pty

// ExitStatus is how a child ended: the code it exited with, or the signal
// that killed it. Windows has no signals, and reports a crash as an NTSTATUS
// exit code instead, such as 0xC0000005 for an access violation.
pub struct ExitStatus {
pub:
	code   int
	signal int
}

// crashed reports whether the child was killed rather than exiting
pub fn (s ExitStatus) crashed() bool {
	return s.signal != 0 || u32(s.code) >= 0xC0000000
}

pub fn (s ExitStatus) str() string {
	if s.signal != 0 {
		return 'killed by signal ${s.signal}'
	}
	if u32(s.code) >= 0xC0000000 {
		return 'crashed with NTSTATUS 0x${u32(s.code):08X}'
	}
	return 'exited with code ${s.code}'
}
