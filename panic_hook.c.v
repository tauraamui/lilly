// Copyright 2024 The Lilly Editor contributors
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

#include <fcntl.h>

fn C.open(const_pathname &char, flags int, mode int) int

fn persist_stderr_to_disk() {
	fd := C.open(c'lilly.panic.log', C.O_CREAT | C.O_WRONLY | C.O_APPEND, 0o666)
	C.dup2(fd, C.STDERR_FILENO)
}
