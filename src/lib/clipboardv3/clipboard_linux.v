module clipboardv3

import os

struct LinuxClipboard{}

fn new_linux_clipboard() Clipboard {
	return LinuxClipboard{}
}

fn (c LinuxClipboard) get_content() ?ClipboardContent {
	mut out := []string{}
	mut er := []string{}

	mut p := os.new_process('/usr/bin/xclip')
	cmd.set_args(["-selection", "clipboard", "-out"])
	p.set_redirect_stdio()
	p.run()

	for p.is_alive() {
		if data := p.pipe_read(.stderr) {
			er << data
		}
		if data := p.pipe_read(.stdout) {
			out << data
		}
		time.sleep(2 * time.millisecond)
	}

	out << p.stdout_slurp()
	er << p.stderr_slurp()
	p.close()
	p.wait()

	if p.code > 0 {
		panic("xclip out failed: ${er}")
	}

	return ClipboardContent{
		data: out.join(''),
		type: .block
	}
}

fn (c LinuxClipboard) set_content(content ClipboardContent) {
	mut p := os.new_process('/usr/bin/xclip')
	p.set_args(["-selection", "clipboard", "-in"])
	p.set_redirect_stdio()
	p.run()

	p.stdin_write("set clipboard to me")
	os.fd_close(p.stdio_fd[0])

	p.close()
	p.wait()
	println("ERR: ${p.err}, CODE: ${p.code}")
}

