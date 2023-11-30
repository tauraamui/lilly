#include <fcntl.h>

fn C.open(const_pathname &char, flags int, mode int) int

fn persist_stderr_to_disk() {
	fd := C.open(c'lilly.panic.log', C.O_CREAT | C.O_WRONLY | C.O_APPEND, 0o666)
	C.dup2(fd, C.STDERR_FILENO)
}
